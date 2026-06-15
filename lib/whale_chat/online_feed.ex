defmodule WhaleChat.OnlineFeed do
  @moduledoc false

  import WhaleChat.Value, only: [float: 1, int: 1, str: 1, truthy?: 1]

  alias Ecto.Adapters.SQL
  alias WhaleChat.Chat.SteamProfiles
  alias WhaleChat.CountryNames
  alias WhaleChat.LegacyPaths
  alias WhaleChat.Repo
  alias WhaleChat.Tf2Classes
  alias WhaleChat.WeaponCategories

  require Logger

  @weapon_category_metadata WeaponCategories.metadata()

  @max_weapon_slots 3
  @server_fresh_seconds 180
  @default_visible_max 32
  @default_avatar_url "/stats/assets/whaley-avatar.jpg"
  @default_game_name "TF2"
  @default_game_url "440"

  @weapon_category_columns Enum.flat_map(Map.keys(@weapon_category_metadata), fn slug ->
                             [
                               {"shots_#{slug}", "0"},
                               {"hits_#{slug}", "0"}
                             ]
                           end)

  @weapon_slot_columns Enum.flat_map(1..@max_weapon_slots, fn slot ->
                         [
                           {"weapon#{slot}_name", "''"},
                           {"weapon#{slot}_accuracy", "NULL"},
                           {"weapon#{slot}_shots", "0"},
                           {"weapon#{slot}_hits", "0"}
                         ]
                       end)

  @online_column_defaults [
                            {"steamid", "''"},
                            {"personaname", "''"},
                            {"class", "0"},
                            {"team", "0"},
                            {"alive", "0"},
                            {"is_spectator", "0"},
                            {"is_admin", "0"},
                            {"kills", "0"},
                            {"deaths", "0"},
                            {"assists", "0"},
                            {"damage", "0"},
                            {"damage_taken", "0"},
                            {"healing", "0"},
                            {"headshots", "0"},
                            {"backstabs", "0"},
                            {"shots", "0"},
                            {"hits", "0"}
                          ] ++
                            @weapon_category_columns ++
                            @weapon_slot_columns ++
                            [
                              {"playtime", "0"},
                              {"total_ubers", "0"},
                              {"classes_mask", "0"},
                              {"time_connected", "0"},
                              {"visible_max", Integer.to_string(@default_visible_max)},
                              {"map_name", "''"},
                              {"last_update", "UNIX_TIMESTAMP()"}
                            ]

  @server_column_defaults [
    {"ip", "''"},
    {"port", "0"},
    {"playercount", "0"},
    {"visible_max", Integer.to_string(@default_visible_max)},
    {"map", "''"},
    {"city", "''"},
    {"country", "''"},
    {"flags", "''"},
    {"last_update", "UNIX_TIMESTAMP()"},
    {"game", "'#{@default_game_name}'"},
    {"game_url", "'#{@default_game_url}'"}
  ]

  def payload do
    now = System.system_time(:second)

    with {:ok, players} <- fetch_online_players() do
      servers =
        case fetch_servers(now) do
          {:ok, servers} ->
            servers

          {:error, reason} ->
            log_online_error("server fetch failed", reason)
            []
        end

      players
      |> enrich_players()
      |> build_response(servers, now)
    else
      {:error, reason} ->
        log_online_error("player fetch failed", reason)
        %{"success" => false, "error" => "internal_error"}
    end
  rescue
    error ->
      log_online_error("payload crashed", error)
      %{"success" => false, "error" => "internal_error"}
  end

  def page_config do
    %{
      default_avatar_url:
        Application.get_env(:whale_chat, :default_avatar_url, @default_avatar_url),
      class_icon_base: System.get_env("WT_CLASS_ICON_BASE") || "/leaderboard/",
      class_metadata: Tf2Classes.online_metadata()
    }
  end

  defp fetch_online_players do
    with {:ok, columns} <- table_columns("whaletracker_online") do
      sql =
        "SELECT " <>
          select_clause(@online_column_defaults, columns) <>
          " FROM whaletracker_online" <>
          order_by_clause(columns, "last_update", "DESC", "steamid", "ASC")

      query_mapped_rows(sql, [])
    end
  end

  defp fetch_servers(now) do
    cutoff = now - @server_fresh_seconds

    with {:ok, columns} <- table_columns("whaletracker_servers") do
      {where_clause, params} = freshness_filter(columns, cutoff)

      sql =
        "SELECT " <>
          select_clause(@server_column_defaults, columns) <>
          " FROM whaletracker_servers" <>
          where_clause <>
          order_by_clause(columns, "port", "ASC", "last_update", "DESC")

      case query_mapped_rows(sql, params) do
        {:ok, rows} -> {:ok, build_server_rows(rows)}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defp query_mapped_rows(sql, params) do
    case SQL.query(Repo, sql, params) do
      {:ok, %{rows: rows, columns: columns}} -> {:ok, map_rows(rows, columns)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp table_columns(table) when table in ["whaletracker_online", "whaletracker_servers"] do
    case SQL.query(Repo, "SHOW COLUMNS FROM #{table}", []) do
      {:ok, %{rows: rows}} ->
        columns =
          rows
          |> Enum.map(fn
            [field | _] -> str(field)
            %{"Field" => field} -> str(field)
            %{Field: field} -> str(field)
            _ -> ""
          end)
          |> Enum.reject(&(&1 == ""))
          |> MapSet.new()

        {:ok, columns}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp select_clause(column_defaults, columns) do
    column_defaults
    |> Enum.map(fn {column, default_expr} ->
      if MapSet.member?(columns, column), do: column, else: "#{default_expr} AS #{column}"
    end)
    |> Enum.join(", ")
  end

  defp freshness_filter(columns, cutoff) do
    if MapSet.member?(columns, "last_update") do
      {" WHERE last_update >= ?", [cutoff]}
    else
      {"", []}
    end
  end

  defp order_by_clause(
         columns,
         primary_column,
         primary_direction,
         fallback_column,
         fallback_direction
       ) do
    cond do
      MapSet.member?(columns, primary_column) ->
        " ORDER BY #{primary_column} #{primary_direction}"

      MapSet.member?(columns, fallback_column) ->
        " ORDER BY #{fallback_column} #{fallback_direction}"

      true ->
        ""
    end
  end

  defp build_server_rows(rows) do
    rows
    |> Enum.map(fn server ->
      host_ip = str(server["ip"])
      host_port = int(server["port"])
      map_name = str(server["map"])

      game_name =
        case str(server["game"]) do
          "" -> @default_game_name
          game -> game
        end

      game_url =
        case str(server["game_url"]) do
          "" -> @default_game_url
          app_id -> app_id
        end

      country_code = server |> Map.get("country") |> CountryNames.normalize_code()

      %{
        "host_ip" => host_ip,
        "host_port" => host_port,
        "map_name" => map_name,
        "game" => game_name,
        "game_url" => game_url,
        "player_count" => int(server["playercount"]),
        "visible_max" => int(server["visible_max"]),
        "map_image" => resolve_map_image(map_name),
        "city" => str(server["city"]),
        "country_code" => country_code,
        "country_name" => CountryNames.display_name(country_code),
        "extra_flags" => parse_flags(server["flags"]),
        "last_update" => int(server["last_update"])
      }
    end)
  end

  defp enrich_players(players) do
    steam_ids =
      players
      |> Enum.map(&str(&1["steamid"]))
      |> Enum.reject(&(&1 == ""))
      |> Enum.uniq()

    profiles = fetch_steam_profiles(steam_ids)
    admin_flags = admin_flags_for_ids(steam_ids)
    default_avatar = Application.get_env(:whale_chat, :default_avatar_url, @default_avatar_url)

    Enum.map(players, fn row ->
      row = normalize_online_player(row)
      steamid = str(row["steamid"])
      profile = Map.get(profiles, steamid, %{})

      personaname =
        case str(profile["personaname"]) do
          "" -> str(row["personaname"])
          name -> name
        end

      avatar =
        case str(profile["avatarfull"]) do
          "" -> default_avatar
          url -> url
        end

      row =
        row
        |> Map.put("personaname", if(personaname == "", do: steamid, else: personaname))
        |> Map.put("avatar", avatar)
        |> Map.put(
          "profileurl",
          if(steamid != "", do: "https://steamcommunity.com/profiles/" <> steamid, else: nil)
        )
        |> Map.put(
          "is_admin",
          if(Map.get(admin_flags, steamid, false), do: 1, else: int(row["is_admin"]))
        )

      {weapon_summary, active_acc} = weapon_summary_for_row(row)

      row
      |> Map.put("weapon_accuracy_summary", weapon_accuracy_summary_for_row(row))
      |> Map.put("weapon_category_summary", weapon_summary)
      |> Map.put("active_weapon_accuracy", active_acc)
      |> drop_weapon_slot_fields()
    end)
  end

  defp build_response(players, servers, now) do
    visible_max_from_players =
      players |> List.first() |> then(fn p -> if p, do: int(p["visible_max"]), else: 0 end)

    visible_max =
      if visible_max_from_players > 0, do: visible_max_from_players, else: @default_visible_max

    player_count_guess = length(players)

    map_name_guess =
      players |> List.first() |> then(fn p -> if p, do: str(p["map_name"]), else: "" end)

    {servers, player_count, visible_max, map_name, map_image} =
      if servers != [] do
        aggregate_players = Enum.reduce(servers, 0, fn s, acc -> acc + int(s["player_count"]) end)
        aggregate_visible = Enum.reduce(servers, 0, fn s, acc -> acc + int(s["visible_max"]) end)
        first_server = hd(servers)

        {
          servers,
          if(aggregate_players > 0, do: aggregate_players, else: player_count_guess),
          if(aggregate_visible > 0, do: aggregate_visible, else: visible_max),
          if(map_name_guess != "", do: map_name_guess, else: str(first_server["map_name"])),
          str(first_server["map_image"])
        }
      else
        fallback_server = %{
          "host_ip" => "",
          "host_port" => 0,
          "map_name" => map_name_guess,
          "game" => @default_game_name,
          "game_url" => @default_game_url,
          "player_count" => player_count_guess,
          "visible_max" => visible_max,
          "map_image" => resolve_map_image(map_name_guess),
          "last_update" => now,
          "city" => "",
          "country_code" => "",
          "country_name" => "",
          "extra_flags" => []
        }

        {[fallback_server], player_count_guess, visible_max, map_name_guess,
         str(fallback_server["map_image"])}
      end

    %{
      "success" => true,
      "updated" => now,
      "visible_max" => visible_max,
      "visible_max_players" => visible_max,
      "player_count" => player_count,
      "map_name" => map_name,
      "map_image" => map_image,
      "servers" => servers,
      "players" => players
    }
  end

  defp normalize_online_player(row) do
    row
    |> Map.update("shots", 0, &int/1)
    |> Map.update("hits", 0, &int/1)
    |> Map.update("classes_mask", 0, &int/1)
    |> Enum.into(%{}, fn {k, v} -> {k, normalize_scalar(v)} end)
  end

  defp normalize_scalar(v) when is_integer(v) or is_float(v) or is_boolean(v) or is_nil(v), do: v
  defp normalize_scalar(v), do: v

  defp weapon_accuracy_summary_for_row(row) do
    Enum.reduce(1..@max_weapon_slots, [], fn slot, acc ->
      name = row["weapon#{slot}_name"] |> str() |> String.trim()
      accuracy = row["weapon#{slot}_accuracy"]
      shots = int(row["weapon#{slot}_shots"])
      hits = int(row["weapon#{slot}_hits"])

      if name == "" or is_nil(accuracy) or shots <= 0 do
        acc
      else
        acc ++
          [%{"name" => name, "accuracy" => float(accuracy), "shots" => shots, "hits" => hits}]
      end
    end)
  end

  defp weapon_summary_for_row(row) do
    summary =
      @weapon_category_metadata
      |> Enum.reduce([], fn {slug, meta}, acc ->
        shots = int(row["shots_#{slug}"])
        hits = int(row["hits_#{slug}"])

        if shots <= 0 do
          acc
        else
          acc ++
            [
              %{
                "slug" => slug,
                "label" => meta.label,
                "shots" => shots,
                "hits" => hits,
                "accuracy" => hits / max(shots, 1) * 100.0
              }
            ]
        end
      end)
      |> Enum.sort_by(fn item -> {-int(item["shots"]), -float(item["accuracy"])} end)
      |> fallback_overall_weapon_summary(row)

    {summary, List.first(summary)}
  end

  defp fallback_overall_weapon_summary([], row) do
    {total_shots, total_hits} = total_weapon_accuracy_counts(row)

    if total_shots > 0 do
      [
        %{
          "slug" => "overall",
          "label" => "Overall",
          "shots" => total_shots,
          "hits" => total_hits,
          "accuracy" => total_hits / max(total_shots, 1) * 100.0
        }
      ]
    else
      []
    end
  end

  defp fallback_overall_weapon_summary(summary, _row), do: summary

  defp total_weapon_accuracy_counts(row) do
    pairs = [
      {"shots_shotguns", "hits_shotguns"},
      {"shots_scatterguns", "hits_scatterguns"},
      {"shots_pistols", "hits_pistols"},
      {"shots_rocketlaunchers", "hits_rocketlaunchers"},
      {"shots_grenadelaunchers", "hits_grenadelaunchers"},
      {"shots_stickylaunchers", "hits_stickylaunchers"},
      {"shots_snipers", "hits_snipers"},
      {"shots_revolvers", "hits_revolvers"}
    ]

    {total_shots, total_hits} =
      Enum.reduce(pairs, {0, 0}, fn {shots_key, hits_key}, {s_acc, h_acc} ->
        {s_acc + int(row[shots_key]), h_acc + int(row[hits_key])}
      end)

    if total_shots == 0 and Map.has_key?(row, "shots") and Map.has_key?(row, "hits") do
      {int(row["shots"]), int(row["hits"])}
    else
      {total_shots, total_hits}
    end
  end

  defp drop_weapon_slot_fields(row) do
    row =
      Enum.reduce(1..@max_weapon_slots, row, fn slot, acc ->
        acc
        |> Map.delete("weapon#{slot}_name")
        |> Map.delete("weapon#{slot}_accuracy")
        |> Map.delete("weapon#{slot}_shots")
        |> Map.delete("weapon#{slot}_hits")
      end)

    row
  end

  defp resolve_map_image(map_name) do
    safe =
      map_name
      |> str()
      |> String.trim()
      |> case do
        "" -> ""
        v -> Regex.replace(~r/[^a-zA-Z0-9_\-]/, v, "")
      end

    cond do
      safe == "" ->
        nil

      File.exists?(Path.join(LegacyPaths.playercount_widget_dir(), "#{safe}.jpg")) ->
        "/playercount_widget/#{URI.encode(safe)}.jpg"

      true ->
        "https://image.gametracker.com/images/maps/160x120/tf2/#{URI.encode(safe)}.jpg"
    end
  end

  defp parse_flags(nil), do: []

  defp parse_flags(value) do
    value
    |> str()
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp fetch_steam_profiles([]), do: %{}

  defp fetch_steam_profiles(ids) do
    SteamProfiles.fetch_many(ids) || %{}
  rescue
    _ -> %{}
  end

  defp admin_flags_for_ids([]), do: %{}

  defp admin_flags_for_ids(ids) do
    cache_file = LegacyPaths.admin_cache_file()

    with {:ok, json} <- File.read(cache_file),
         {:ok, %{"admins" => admins}} <- Jason.decode(json) do
      ids
      |> Enum.reduce(%{}, fn id, acc -> Map.put(acc, id, truthy?(Map.get(admins, id))) end)
    else
      _ -> %{}
    end
  end

  defp log_online_error(context, reason) do
    Logger.debug(fn -> "[OnlineFeed] #{context}: #{inspect(reason)}" end)
  end

  defp map_rows(rows, columns) do
    Enum.map(rows, fn row -> Enum.zip(columns, row) |> Map.new() end)
  end

end
