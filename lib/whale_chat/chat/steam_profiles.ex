defmodule WhaleChat.Chat.SteamProfiles do
  @moduledoc false

  alias WhaleChat.LegacyPaths

  @cache_table :kogasa_frontend_steam_profile_cache
  @ttl_seconds 24 * 3600
  @php_cache_ttl_seconds 24 * 3600

  def fetch_many(steam_ids) when is_list(steam_ids) do
    ids =
      steam_ids
      |> Enum.filter(&is_binary/1)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.uniq()

    cond do
      ids == [] -> %{}
      true -> cached_and_fetch(ids)
    end
  end

  def fetch_many(_), do: %{}

  def search_cached_ids(term, limit \\ 200)

  def search_cached_ids(term, limit) when is_binary(term) and is_integer(limit) do
    query =
      term
      |> String.trim()
      |> String.downcase()

    cond do
      query == "" ->
        []

      String.length(query) < 2 ->
        []

      limit <= 0 ->
        []

      true ->
        ensure_cache()
        now = System.system_time(:second)
        ets_matches = search_ets_cached_ids(query, now, limit)
        seen = MapSet.new(ets_matches)
        remaining = max(limit - length(ets_matches), 0)

        ets_matches ++ search_disk_cached_ids(query, seen, remaining)
    end
  end

  def search_cached_ids(_, _), do: []

  defp cached_and_fetch(ids) do
    ensure_cache()
    now = System.system_time(:second)

    {cached_ets, missing_after_ets} =
      Enum.reduce(ids, {%{}, []}, fn sid, {acc, miss} ->
        case :ets.lookup(@cache_table, sid) do
          [{^sid, profile, expires_at}] when expires_at > now ->
            {Map.put(acc, sid, profile), miss}

          _ ->
            {acc, [sid | miss]}
        end
      end)

    {cached_disk, stale_disk, missing} =
      missing_after_ets
      |> Enum.reverse()
      |> Enum.reduce({%{}, %{}, []}, fn sid, {fresh_acc, stale_acc, miss_acc} ->
        case read_disk_cached_profile(sid, now) do
          {:fresh, profile} ->
            :ets.insert(@cache_table, {sid, profile, now + @ttl_seconds})
            {Map.put(fresh_acc, sid, profile), stale_acc, miss_acc}

          {:stale, profile} ->
            {fresh_acc, Map.put(stale_acc, sid, profile), [sid | miss_acc]}

          :missing ->
            {fresh_acc, stale_acc, [sid | miss_acc]}
        end
      end)

    fetched =
      case steam_api_key() do
        "" ->
          %{}

        _ ->
          missing
          |> Enum.reverse()
          |> Enum.chunk_every(100)
          |> Enum.reduce(%{}, fn chunk, acc -> Map.merge(acc, fetch_chunk(chunk)) end)
      end

    Enum.each(fetched, fn {sid, profile} ->
      :ets.insert(@cache_table, {sid, profile, now + @ttl_seconds})
    end)

    stale_fallback =
      missing
      |> Enum.reject(&Map.has_key?(fetched, &1))
      |> Enum.reduce(%{}, fn sid, acc ->
        case Map.fetch(stale_disk, sid) do
          {:ok, profile} ->
            :ets.insert(@cache_table, {sid, profile, now + 300})
            Map.put(acc, sid, profile)

          :error ->
            acc
        end
      end)

    cached_ets
    |> Map.merge(cached_disk)
    |> Map.merge(fetched)
    |> Map.merge(stale_fallback)
  end

  defp fetch_chunk([]), do: %{}

  defp fetch_chunk(chunk) do
    ids = Enum.join(chunk, ",")

    url =
      "https://api.steampowered.com/ISteamUser/GetPlayerSummaries/v0002/?key=#{URI.encode(steam_api_key())}&steamids=#{URI.encode(ids)}"

    try do
      case Req.get(url, receive_timeout: 2_500, connect_options: [timeout: 2_500]) do
        {:ok, %{status: 200, body: %{"response" => %{"players" => players}}}}
        when is_list(players) ->
          Map.new(players, fn player ->
            sid = player["steamid"]

            {sid,
             %{
               "steamid" => sid,
               "personaname" => player["personaname"],
               "avatarfull" => player["avatarfull"],
               "profileurl" => player["profileurl"]
             }}
          end)

        _ ->
          %{}
      end
    rescue
      _ -> %{}
    end
  end

  defp steam_api_key, do: Application.get_env(:kogasa_frontend, :steam_api_key, "")

  defp read_disk_cached_profile(steamid, now) do
    path = disk_cache_profile_path(steamid)

    with true <- File.exists?(path),
         {:ok, body} <- File.read(path),
         {:ok, %{} = profile} <- Jason.decode(body) do
      normalized = normalize_disk_profile(profile, steamid)

      case File.stat(path, time: :posix) do
        {:ok, stat} when is_integer(stat.mtime) ->
          if now - stat.mtime <= @php_cache_ttl_seconds do
            {:fresh, normalized}
          else
            {:stale, normalized}
          end

        _ ->
          {:stale, normalized}
      end
    else
      _ -> :missing
    end
  end

  defp normalize_disk_profile(profile, steamid) do
    avatarfull = profile |> Map.get("avatarfull") |> normalize_cached_avatar(profile)

    profile
    |> Map.put_new("steamid", steamid)
    |> Map.put("avatarfull", avatarfull)
    |> Map.put_new("personaname", steamid)
  end

  defp normalize_cached_avatar(nil, profile), do: normalize_cached_avatar("", profile)

  defp normalize_cached_avatar(avatarfull, profile) when is_binary(avatarfull) do
    avatar = String.trim(avatarfull)
    avatar_cached = profile["avatar_cached"] |> to_string_safe() |> String.trim()
    avatar_source = profile["avatar_source"] |> to_string_safe() |> String.trim()

    cond do
      avatar != "" and String.starts_with?(avatar, "/stats/cache/") and
          avatar_cache_exists?(avatar) ->
        avatar

      avatar != "" and String.starts_with?(avatar, "/stats/cache/") ->
        if avatar_source != "", do: avatar_source, else: avatar

      avatar != "" ->
        avatar

      avatar_cached != "" ->
        local_url = "/stats/cache/" <> Path.basename(avatar_cached)
        if avatar_cache_exists?(local_url), do: local_url, else: avatar_source

      avatar_source != "" ->
        avatar_source

      true ->
        ""
    end
  end

  defp normalize_cached_avatar(_other, profile), do: normalize_cached_avatar("", profile)

  defp avatar_cache_exists?("/stats/cache/" <> basename) do
    File.exists?(Path.join(disk_cache_dir(), Path.basename(basename)))
  end

  defp avatar_cache_exists?(_), do: false

  defp disk_cache_profile_path(steamid) do
    sanitized = String.replace(steamid, ~r/\D+/, "")
    Path.join(disk_cache_dir(), sanitized <> ".json")
  end

  defp disk_cache_dir do
    LegacyPaths.stats_cache_dir()
  end

  defp to_string_safe(nil), do: ""
  defp to_string_safe(value) when is_binary(value), do: value
  defp to_string_safe(value), do: to_string(value)

  defp ensure_cache do
    case :ets.whereis(@cache_table) do
      :undefined -> :ets.new(@cache_table, [:named_table, :public, :set, read_concurrency: true])
      _ -> :ok
    end
  rescue
    _ -> :ok
  end

  defp search_ets_cached_ids(query, now, limit) do
    @cache_table
    |> :ets.tab2list()
    |> Enum.reduce_while([], fn
      {steamid, profile, expires_at}, acc
      when is_binary(steamid) and is_map(profile) and expires_at > now ->
        name =
          profile
          |> Map.get("personaname", "")
          |> to_string_safe()
          |> String.downcase()

        cond do
          name == "" or not String.contains?(name, query) ->
            {:cont, acc}

          length(acc) >= limit ->
            {:halt, acc}

          true ->
            {:cont, [steamid | acc]}
        end

      _, acc ->
        {:cont, acc}
    end)
    |> Enum.reverse()
  end

  defp search_disk_cached_ids(_query, _seen, limit) when limit <= 0, do: []

  defp search_disk_cached_ids(query, seen, limit) do
    case File.ls(disk_cache_dir()) do
      {:ok, files} ->
        files
        |> Enum.reduce_while([], fn file, acc ->
          cond do
            length(acc) >= limit ->
              {:halt, acc}

            not String.ends_with?(file, ".json") ->
              {:cont, acc}

            true ->
              steamid = String.trim_trailing(file, ".json")

              cond do
                MapSet.member?(seen, steamid) ->
                  {:cont, acc}

                true ->
                  path = Path.join(disk_cache_dir(), file)

                  case File.read(path) do
                    {:ok, body} ->
                      case Jason.decode(body) do
                        {:ok, %{} = profile} ->
                          name =
                            profile
                            |> normalize_disk_profile(steamid)
                            |> Map.get("personaname", "")
                            |> to_string_safe()
                            |> String.downcase()

                          if name != "" and String.contains?(name, query) do
                            {:cont, [steamid | acc]}
                          else
                            {:cont, acc}
                          end

                        _ ->
                          {:cont, acc}
                      end

                    _ ->
                      {:cont, acc}
                  end
              end
          end
        end)
        |> Enum.reverse()

      _ ->
        []
    end
  end
end
