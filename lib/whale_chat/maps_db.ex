defmodule WhaleChat.MapsDb do
  @moduledoc false

  import Ecto.Query

  alias WhaleChat.MapsDb.MapMeta
  alias WhaleChat.Chat.SteamProfiles
  alias WhaleChat.Repo

  @gamemode_names ~w(arena koth payload payloadrace ctf 5cp adcp tc medieval pd tr dm ultiduo rd pass mvm kotf dom default)
  @page_gamemode_names ~w(arena koth payload payloadrace ctf 5cp adcp tc medieval pd tr dm ultiduo rd pass mvm kotf dom symmetrical asymmetrical default)
  @api_category_order ~w(koth cp pl plr ctf pd sd arena zi vsh mge tc tr dm ultiduo rd pass mvm kotf dom)
  @page_category_order ~w(gamemode koth cp pl plr ctf pd sd arena zi vsh mge tc tr dm ultiduo rd pass mvm kotf dom)
  @population_statistics_table "server_population_statistics_samples"
  @map_session_statistics_table "map_statistics_sessions"
  @vote_statistics_table "nativevotes_statistics_events"
  @category_label_map %{
    "koth" => "KOTH maps",
    "cp" => "Control Point maps",
    "pl" => "Payload maps",
    "plr" => "Payload Race maps",
    "ctf" => "Capture the Flag maps",
    "pd" => "Player Destruction maps",
    "sd" => "SD maps",
    "arena" => "Arena maps",
    "zi" => "Zombie Infection maps",
    "vsh" => "Vs. Saxton Hale maps",
    "mge" => "MGE maps",
    "tc" => "Terrain Control maps",
    "tr" => "Training maps",
    "dm" => "Deathmatch maps",
    "ultiduo" => "Ultiduo maps",
    "rd" => "Robot Destruction maps",
    "pass" => "Pass Time maps",
    "mvm" => "Mann vs. Machine maps",
    "kotf" => "King of the Flag maps",
    "dom" => "Domination maps",
    "gamemode" => "Gamemode configs"
  }
  @sub_category_order ["harvest"]
  @sub_category_label_map %{"harvest" => "Harvest-type maps"}

  def config do
    %{
      maps_dir:
        Application.get_env(:whale_chat, :mapsdb_dir, "/home/kogasa/hlserver/tf2/tf/cfg/mapsdb"),
      tf_cfg_dir:
        Application.get_env(:whale_chat, :mapsdb_tf_cfg_dir, "/home/kogasa/hlserver/tf2/tf/cfg"),
      preview_dir:
        Application.get_env(
          :whale_chat,
          :mapsdb_preview_dir,
          "/var/www/kogasatopia/playercount_widget"
        ),
      admin_cache_file:
        Application.get_env(
          :whale_chat,
          :mapsdb_admin_cache_file,
          "/var/www/kogasatopia/stats/cache/admins_cache.json"
        )
    }
  end

  def page_data(steamid \\ nil) do
    cfg = config()
    maps_dir_missing = not File.dir?(cfg.maps_dir)
    is_logged_in = is_binary(steamid) and steamid != ""
    is_admin = is_logged_in and admin?(steamid)
    can_edit_maps = is_logged_in and is_admin
    chart_bundle = popularity_chart_bundle()

    viewer_profile =
      case steamid do
        sid when is_binary(sid) and sid != "" ->
          SteamProfiles.fetch_many([sid])
          |> Map.get(sid)
          |> case do
            %{} = profile -> %{personaname: profile["personaname"], avatar: profile["avatarfull"]}
            _ -> nil
          end

        _ ->
          nil
      end

    %{
      maps_dir: cfg.maps_dir,
      maps_dir_missing: maps_dir_missing,
      is_logged_in: is_logged_in,
      current_steamid: steamid,
      viewer_profile: viewer_profile,
      is_admin: is_admin,
      can_edit_maps: can_edit_maps,
      popular_maps: fetch_map_popularity(25),
      popularity_chart: chart_bundle.chart,
      popularity_active_hours: chart_bundle.active_hours,
      map_analytics: map_detail_analytics(),
      map_previews: map_previews(cfg.preview_dir),
      map_sections: if(maps_dir_missing, do: [], else: build_page_sections(cfg)),
      login_url: "/mapsdb/login.php?return=" <> URI.encode("/mapsdb"),
      logout_url: "/mapsdb/login.php?action=logout&return=" <> URI.encode("/mapsdb")
    }
  end

  def admin?(nil), do: false
  def admin?(""), do: false

  def admin?(steamid) when is_binary(steamid) do
    case File.read(config().admin_cache_file) do
      {:ok, json} ->
        case Jason.decode(json) do
          {:ok, %{"admins" => admins}} when is_map(admins) -> truthy?(Map.get(admins, steamid))
          _ -> false
        end

      _ ->
        false
    end
  end

  def list_api_maps do
    cfg = config()
    files = Path.wildcard(Path.join(cfg.maps_dir, "*.cfg"))

    rows =
      files
      |> Enum.filter(&File.regular?/1)
      |> Enum.map(fn file ->
        stat = File.stat!(file)
        name = Path.rootname(Path.basename(file))

        %{
          "name" => name,
          "modified" => mtime_unix(stat),
          "size" => stat.size
        }
      end)
      |> Enum.sort_by(&String.downcase(&1["name"]))

    names = Enum.map(rows, & &1["name"])
    categories = fetch_categories(names)
    gamemode_order = Enum.with_index(Enum.map(@gamemode_names, &String.downcase/1)) |> Map.new()
    gamemode_set = Map.keys(gamemode_order) |> MapSet.new()

    enriched =
      Enum.map(rows, fn row ->
        name = row["name"]
        lower = String.downcase(name)
        type = if MapSet.member?(gamemode_set, lower), do: "gamemode", else: "map"

        row
        |> Map.put("category", Map.get(categories, name, ""))
        |> Map.put("type", type)
        |> Map.put("order", if(type == "gamemode", do: Map.get(gamemode_order, lower), else: nil))
      end)

    {gamemodes, maps} = Enum.split_with(enriched, &(&1["type"] == "gamemode"))

    gamemodes_sorted =
      Enum.sort_by(gamemodes, fn row ->
        {row["order"] || 99_999, String.downcase(row["name"])}
      end)

    grouped =
      Enum.group_by(maps, fn row ->
        cat = row["category"]
        if cat == "", do: "_other", else: String.downcase(cat)
      end)

    ordered_maps =
      @api_category_order
      |> Enum.reduce({[], grouped}, fn cat_key, {acc, buckets} ->
        case Map.pop(buckets, cat_key) do
          {nil, rest} -> {acc, rest}
          {bucket, rest} -> {acc ++ Enum.sort_by(bucket, &String.downcase(&1["name"])), rest}
        end
      end)
      |> then(fn {acc, buckets} ->
        tail =
          buckets
          |> Enum.sort_by(fn {k, _} -> k end)
          |> Enum.flat_map(fn {_k, bucket} ->
            Enum.sort_by(bucket, &String.downcase(&1["name"]))
          end)

        acc ++ tail
      end)

    ordered = gamemodes_sorted ++ ordered_maps

    Enum.map(ordered, &Map.delete(&1, "order"))
  end

  def load_config_file(map, source) do
    with {:ok, src} <- sanitize_source(source),
         {:ok, path, map_name} <- sanitize_map(map, src),
         {:ok, content} <- File.read(path),
         {:ok, stat} <- File.stat(path) do
      {:ok, %{map: map_name, content: content, modified: mtime_unix(stat)}}
    else
      {:error, _} = err -> err
      {:file_error, reason} -> {:error, {:io, reason}}
    end
  end

  def save_config_file(map, source, content) when is_binary(content) do
    with {:ok, src} <- sanitize_source(source),
         {:ok, path, map_name} <- sanitize_map(map, src),
         :ok <- write_file(path, content),
         {:ok, stat} <- File.stat(path) do
      {:ok, %{map: map_name, modified: mtime_unix(stat), bytes: stat.size || byte_size(content)}}
    else
      {:error, _} = err -> err
      {:file_error, reason} -> {:error, {:io, reason}}
    end
  end

  def mass_edit(search, replace) when is_binary(search) and is_binary(replace) do
    if String.trim(search) == "" do
      {:error, :search_required}
    else
      cfg = config()

      {modified, total} =
        Path.wildcard(Path.join(cfg.maps_dir, "*.cfg"))
        |> Enum.reduce({[], 0}, fn file, {mods, total_replacements} ->
          if File.regular?(file) do
            case File.read(file) do
              {:ok, contents} ->
                {updated, count} = replace_count(contents, search, replace)

                if count > 0 do
                  case write_file(file, updated) do
                    :ok ->
                      file_name = Path.basename(file)

                      {[%{file: file_name, replacements: count} | mods],
                       total_replacements + count}

                    _ ->
                      {mods, total_replacements}
                  end
                else
                  {mods, total_replacements}
                end

              _ ->
                {mods, total_replacements}
            end
          else
            {mods, total_replacements}
          end
        end)

      {:ok,
       %{
         modified: Enum.reverse(modified),
         filesEdited: length(modified),
         totalReplacements: total
       }}
    end
  end

  def build_page_sections(cfg \\ config()) do
    maps_dir = cfg.maps_dir
    tf_cfg_dir = cfg.tf_cfg_dir

    map_names =
      Path.wildcard(Path.join(maps_dir, "*.cfg"))
      |> Enum.filter(&File.regular?/1)
      |> Enum.map(&Path.rootname(Path.basename(&1)))
      |> Enum.sort_by(&String.downcase/1)

    map_meta = fetch_meta(map_names)

    sections =
      []
      |> maybe_add_server_configs(tf_cfg_dir)
      |> maybe_add_mapcycles(tf_cfg_dir)
      |> add_playercount_settings()
      |> maybe_add_category_configs(map_meta)

    map_sections = build_map_sections(map_names, map_meta)
    sections ++ map_sections
  end

  def fetch_map_popularity(limit \\ 50) do
    lim = max(1, min(limit, 500))

    Repo.all(
      from m in MapMeta,
        order_by: [desc: m.popularity, asc: m.map_name],
        limit: ^lim,
        select: %{
          map_name: m.map_name,
          category: m.category,
          sub_category: m.sub_category,
          popularity: m.popularity
        }
    )
  end

  def map_detail_analytics do
    rows = fetch_map_detail_rows(40)

    %{
      rows: rows,
      scores: build_map_scores(rows),
      top_sessions: fetch_session_extremes(:top, 8),
      worst_sessions: fetch_session_extremes(:worst, 8),
      weekday_hours: fetch_weekday_hour_performance(12),
      first15_chart: fetch_map_curve_chart(rows, 15, 60, 6),
      population_curve_chart: fetch_map_curve_chart(rows, 60, 300, 6),
      vote_table_available: table_exists?(@vote_statistics_table)
    }
  end

  defp fetch_map_detail_rows(limit) do
    lim = max(1, min(limit, 100))

    sessions =
      query_rows("""
      SELECT map_name,
             MIN(gamemode) AS gamemode,
             COUNT(*) AS sessions,
             ROUND(AVG(avg_players), 2) AS avg_players,
             MAX(peak_players) AS peak_players,
             ROUND(SUM(player_seconds) / 3600, 1) AS player_hours,
             SUM(joins) AS joins,
             SUM(leaves) AS leaves
      FROM #{@map_session_statistics_table}
      WHERE peak_players > 0 AND duration >= 300
      GROUP BY map_name
      ORDER BY player_hours DESC, avg_players DESC
      LIMIT #{lim}
      """)

    first15 =
      query_rows("""
      SELECT map_name,
             ROUND(AVG(CASE WHEN map_elapsed_seconds BETWEEN 0 AND 899 THEN player_count END), 2) AS first15_avg,
             ROUND(
               COALESCE(AVG(CASE WHEN map_elapsed_seconds BETWEEN 600 AND 899 THEN player_count END), 0) -
               COALESCE(AVG(CASE WHEN map_elapsed_seconds BETWEEN 0 AND 299 THEN player_count END), 0),
               2
             ) AS first15_growth
      FROM #{@population_statistics_table}
      WHERE map_elapsed_seconds BETWEEN 0 AND 899
        AND player_count > 0
      GROUP BY map_name
      """)
      |> Map.new(fn row -> {row.map_name, row} end)

    best_slots =
      query_rows("""
      SELECT map_name,
             weekday,
             hour_of_day,
             COUNT(*) AS sessions,
             ROUND(AVG(avg_players), 2) AS avg_players
      FROM #{@map_session_statistics_table}
      WHERE peak_players > 0 AND duration >= 300
      GROUP BY map_name, weekday, hour_of_day
      ORDER BY map_name ASC, avg_players DESC, sessions DESC
      """)
      |> Enum.group_by(& &1.map_name)
      |> Map.new(fn {map_name, slots} -> {map_name, List.first(slots)} end)

    vote_pressure = fetch_vote_pressure()

    Enum.map(sessions, fn row ->
      first = Map.get(first15, row.map_name, %{})
      best = Map.get(best_slots, row.map_name)
      votes = Map.get(vote_pressure, row.map_name, %{})

      avg_players = to_float(row.avg_players)
      player_hours = to_float(row.player_hours)
      first15_avg = to_float(Map.get(first, :first15_avg))
      first15_growth = to_float(Map.get(first, :first15_growth))

      %{
        map_name: row.map_name || "",
        gamemode: row.gamemode || "",
        sessions: to_int(row.sessions),
        avg_players: avg_players,
        avg_players_display: format_float(avg_players, 1),
        peak_players: to_int(row.peak_players),
        player_hours: player_hours,
        player_hours_display: format_float(player_hours, 1),
        joins: to_int(row.joins),
        leaves: to_int(row.leaves),
        first15_avg: first15_avg,
        first15_avg_display: format_float(first15_avg, 1),
        first15_growth: first15_growth,
        first15_growth_display: signed_float(first15_growth, 1),
        best_slot: format_slot(best),
        best_slot_avg_display: format_float(Map.get(best || %{}, :avg_players), 1),
        nominations: to_int(Map.get(votes, :nominations)),
        rtvs: to_int(Map.get(votes, :rtvs)),
        vote_options: to_int(Map.get(votes, :vote_options)),
        vote_wins: to_int(Map.get(votes, :vote_wins)),
        eligibility_failures: to_int(Map.get(votes, :eligibility_failures))
      }
    end)
  end

  defp fetch_session_extremes(kind, limit) do
    lim = max(1, min(limit, 25))

    order =
      case kind do
        :worst -> "avg_players ASC, peak_players ASC, duration DESC"
        _ -> "avg_players DESC, peak_players DESC, duration DESC"
      end

    query_rows("""
    SELECT map_name,
           map_session_id,
           started_at,
           duration,
           peak_players,
           avg_players,
           player_seconds,
           joins,
           leaves,
           end_reason
    FROM #{@map_session_statistics_table}
    WHERE peak_players > 0 AND duration >= 600
    ORDER BY #{order}
    LIMIT #{lim}
    """)
    |> Enum.map(fn row ->
      avg_players = to_float(row.avg_players)

      %{
        map_name: row.map_name || "",
        map_session_id: row.map_session_id || "",
        started_at: to_int(row.started_at),
        started_display: format_date(to_int(row.started_at)),
        duration_display: format_duration(to_int(row.duration)),
        peak_players: to_int(row.peak_players),
        avg_players: avg_players,
        avg_players_display: format_float(avg_players, 1),
        player_hours_display: format_float(to_float(row.player_seconds) / 3600.0, 1),
        joins: to_int(row.joins),
        leaves: to_int(row.leaves),
        end_reason: row.end_reason || ""
      }
    end)
  end

  defp fetch_weekday_hour_performance(limit) do
    lim = max(1, min(limit, 48))

    query_rows("""
    SELECT weekday,
           hour_of_day,
           COUNT(*) AS sessions,
           ROUND(AVG(avg_players), 2) AS avg_players,
           MAX(peak_players) AS peak_players,
           ROUND(SUM(player_seconds) / 3600, 1) AS player_hours
    FROM #{@map_session_statistics_table}
    WHERE peak_players > 0 AND duration >= 600
    GROUP BY weekday, hour_of_day
    ORDER BY avg_players DESC, sessions DESC
    LIMIT #{lim}
    """)
    |> Enum.map(fn row ->
      %{
        slot: format_slot(row),
        sessions: to_int(row.sessions),
        avg_players_display: format_float(row.avg_players, 1),
        peak_players: to_int(row.peak_players),
        player_hours_display: format_float(row.player_hours, 1)
      }
    end)
  end

  defp fetch_map_curve_chart(rows, minutes, bucket_seconds, limit) do
    map_names =
      rows
      |> Enum.map(& &1.map_name)
      |> Enum.reject(&(&1 == ""))
      |> Enum.take(limit)

    bucket_count = max(1, div(minutes * 60, bucket_seconds))
    labels = for bucket <- 0..(bucket_count - 1), do: "#{div(bucket * bucket_seconds, 60)}m"

    if map_names == [] do
      %{"labels" => labels, "series" => []}
    else
      rows =
        query_rows("""
        SELECT map_name,
               FLOOR(map_elapsed_seconds / #{bucket_seconds}) AS bucket,
               ROUND(AVG(player_count), 2) AS avg_players
        FROM #{@population_statistics_table}
        WHERE map_name IN (#{sql_string_list(map_names)})
          AND map_elapsed_seconds >= 0
          AND map_elapsed_seconds < #{minutes * 60}
          AND player_count > 0
        GROUP BY map_name, bucket
        ORDER BY map_name ASC, bucket ASC
        """)

      values =
        rows
        |> Enum.group_by(& &1.map_name)
        |> Map.new(fn {map_name, points} ->
          point_map =
            Map.new(points, fn point -> {to_int(point.bucket), to_float(point.avg_players)} end)

          {map_name, point_map}
        end)

      series =
        Enum.map(map_names, fn map_name ->
          %{
            "label" => map_name,
            "data" =>
              for(
                bucket <- 0..(bucket_count - 1),
                do: Map.get(Map.get(values, map_name, %{}), bucket)
              )
          }
        end)

      %{"labels" => labels, "series" => series}
    end
  end

  defp fetch_vote_pressure do
    if table_exists?(@vote_statistics_table) do
      query_rows("""
      SELECT map_name,
             SUM(event_type = 'nomination') AS nominations,
             SUM(event_type = 'rtv') AS rtvs,
             SUM(event_type = 'vote_option') AS vote_options,
             SUM(event_type = 'vote_winner') AS vote_wins,
             SUM(event_type = 'eligibility_failure') AS eligibility_failures
      FROM #{@vote_statistics_table}
      WHERE created_at >= UNIX_TIMESTAMP(DATE_SUB(NOW(), INTERVAL 30 DAY))
        AND map_name <> ''
      GROUP BY map_name
      """)
      |> Map.new(fn row -> {row.map_name, row} end)
    else
      %{}
    end
  end

  defp build_map_scores(rows) do
    metrics =
      Enum.map(rows, fn row ->
        sessions = max(to_int(row.sessions), 1)
        joins_per_session = to_float(row.joins) / sessions
        leaves_per_session = to_float(row.leaves) / sessions
        vote_pressure = to_float(row.rtvs + row.nominations + row.eligibility_failures) / sessions

        %{
          row: row,
          avg_players: to_float(row.avg_players),
          peak_players: to_float(row.peak_players),
          player_hours: to_float(row.player_hours),
          growth: to_float(row.first15_growth),
          joins_per_session: joins_per_session,
          leaves_per_session: leaves_per_session,
          vote_pressure: vote_pressure,
          sessions: sessions
        }
      end)

    ranges =
      for key <- [
            :avg_players,
            :peak_players,
            :player_hours,
            :growth,
            :joins_per_session,
            :leaves_per_session,
            :vote_pressure
          ],
          into: %{} do
        values = Enum.map(metrics, &Map.get(&1, key, 0.0))
        {key, {Enum.min(values, fn -> 0.0 end), Enum.max(values, fn -> 0.0 end)}}
      end

    metrics
    |> Enum.map(fn metric ->
      avg = normalize(metric.avg_players, ranges.avg_players)
      peak = normalize(metric.peak_players, ranges.peak_players)
      hours = normalize(metric.player_hours, ranges.player_hours)
      growth = normalize(metric.growth, ranges.growth)
      joins = normalize(metric.joins_per_session, ranges.joins_per_session)
      leaves = normalize(metric.leaves_per_session, ranges.leaves_per_session)
      pressure = normalize(metric.vote_pressure, ranges.vote_pressure)
      novelty = novelty_score(metric.sessions)

      seed =
        score([growth: 0.40, joins: 0.25, low_avg: 0.20, peak: 0.15], %{
          growth: growth,
          joins: joins,
          low_avg: 1.0 - avg,
          peak: peak
        })

      grow =
        score([growth: 0.45, joins: 0.25, peak: 0.15, hours: 0.15], %{
          growth: growth,
          joins: joins,
          peak: peak,
          hours: hours
        })

      hold =
        score([avg: 0.45, hours: 0.25, peak: 0.20, low_leaves: 0.10], %{
          avg: avg,
          hours: hours,
          peak: peak,
          low_leaves: 1.0 - leaves
        })

      risk =
        score([low_avg: 0.35, leaves: 0.25, low_growth: 0.25, pressure: 0.15], %{
          low_avg: 1.0 - avg,
          leaves: leaves,
          low_growth: 1.0 - growth,
          pressure: pressure
        })

      {category, category_score} =
        choose_map_category(metric.sessions, seed, grow, hold, risk, novelty)

      best_role = max(seed, max(grow, hold))
      normalized_score = clamp(round(best_role * (1.0 - risk / 250.0) + novelty * 0.08), 0, 100)

      %{
        map_name: metric.row.map_name,
        category: category,
        score: normalized_score,
        category_score: category_score,
        seed_score: seed,
        grow_score: grow,
        hold_score: hold,
        risk_score: risk,
        novelty_score: novelty,
        score_display: Integer.to_string(normalized_score),
        category_score_display: Integer.to_string(category_score),
        seed_score_display: Integer.to_string(seed),
        grow_score_display: Integer.to_string(grow),
        hold_score_display: Integer.to_string(hold),
        risk_score_display: Integer.to_string(risk),
        novelty_score_display: Integer.to_string(novelty),
        evidence: score_evidence(metric.row, category)
      }
    end)
    |> Enum.sort_by(fn score -> {-score.score, score.map_name} end)
  end

  defp choose_map_category(sessions, seed, grow, hold, risk, novelty) do
    cond do
      sessions < 3 -> {"novelty", novelty}
      risk >= 72 -> {"risky", risk}
      seed >= grow and seed >= hold and seed >= 55 -> {"seed", seed}
      grow >= seed and grow >= hold and grow >= 55 -> {"grow", grow}
      hold >= 55 -> {"hold", hold}
      true -> {"filler", max(seed, max(grow, hold))}
    end
  end

  defp score(weights, values) do
    weights
    |> Enum.reduce(0.0, fn {key, weight}, acc -> acc + Map.get(values, key, 0.0) * weight end)
    |> Kernel.*(100.0)
    |> round()
    |> clamp(0, 100)
  end

  defp novelty_score(sessions) when sessions < 3, do: 100
  defp novelty_score(sessions) when sessions < 6, do: 70
  defp novelty_score(sessions), do: clamp(40 - sessions * 2, 0, 40)

  defp normalize(_value, {same, same}), do: 0.5

  defp normalize(value, {min_value, max_value}) do
    ((to_float(value) - to_float(min_value)) /
       max(to_float(max_value) - to_float(min_value), 0.0001))
    |> clamp_float(0.0, 1.0)
  end

  defp score_evidence(row, category) do
    case category do
      "seed" ->
        "opening #{row.first15_growth_display}, #{row.joins} joins"

      "grow" ->
        "growth #{row.first15_growth_display}, peak #{row.peak_players}"

      "hold" ->
        "avg #{row.avg_players_display}, #{row.player_hours_display} player-hours"

      "risky" ->
        "growth #{row.first15_growth_display}, #{row.leaves} leaves"

      "novelty" ->
        "#{row.sessions} tracked sessions"

      _ ->
        "avg #{row.avg_players_display}, peak #{row.peak_players}"
    end
  end

  defp clamp(value, min_value, max_value), do: value |> max(min_value) |> min(max_value)
  defp clamp_float(value, min_value, max_value), do: value |> max(min_value) |> min(max_value)

  def popularity_chart_data, do: popularity_chart_bundle().chart
  def popularity_active_hours, do: popularity_chart_bundle().active_hours

  def map_previews(preview_dir \\ config().preview_dir) do
    if File.dir?(preview_dir) do
      preview_dir
      |> File.ls!()
      |> Enum.filter(fn file -> String.ends_with?(String.downcase(file), ".jpg") end)
      |> Enum.map(fn file ->
        name = Path.rootname(file)
        %{"name" => name, "url" => "/playercount_widget/" <> URI.encode(file)}
      end)
      |> Enum.sort_by(&String.downcase(&1["name"]))
    else
      []
    end
  end

  defp popularity_chart_bundle do
    now = System.system_time(:second)

    sql = """
    SELECT sampled_at, player_count
    FROM mapsdb_popularity_log
    WHERE sampled_at >= UNIX_TIMESTAMP(DATE_SUB(NOW(), INTERVAL 90 DAY))
      AND map_name NOT LIKE 'mge\\\\_%' ESCAPE '\\\\'
    ORDER BY sampled_at ASC
    """

    with {:ok, %{rows: rows}} <- Repo.query(sql) do
      build_chart_from_rows(rows, now)
    else
      _ -> %{chart: empty_chart(), active_hours: 0}
    end
  rescue
    _ -> %{chart: empty_chart(), active_hours: 0}
  end

  defp build_chart_from_rows(rows, now) when is_list(rows) do
    entries =
      rows
      |> Enum.map(fn
        [sampled_at, player_count] ->
          %{sampled_at: to_int(sampled_at), player_count: to_int(player_count)}

        %{sampled_at: sampled_at, player_count: player_count} ->
          %{sampled_at: to_int(sampled_at), player_count: to_int(player_count)}

        _ ->
          nil
      end)
      |> Enum.reject(&is_nil/1)

    latest_sample_ts =
      entries
      |> Enum.map(& &1.sampled_at)
      |> Enum.max(fn -> nil end)

    hours_per_range = 24 * 30
    seconds_per_range = hours_per_range * 3600

    anchor_ts =
      if latest_sample_ts do
        div(latest_sample_ts, 3600) * 3600 + 3600
      else
        div(now, 3600) * 3600
      end

    current_start_ts = anchor_ts - seconds_per_range
    previous_start_ts = current_start_ts - seconds_per_range
    earlier_start_ts = previous_start_ts - seconds_per_range

    windows = %{
      "current" => %{start: current_start_ts, end: anchor_ts},
      "previous" => %{start: previous_start_ts, end: current_start_ts},
      "earlier" => %{start: earlier_start_ts, end: previous_start_ts}
    }

    sums =
      Map.new(windows, fn {k, _} -> {k, :array.new(hours_per_range, default: 0.0)} end)

    counts =
      Map.new(windows, fn {k, _} -> {k, :array.new(hours_per_range, default: 0)} end)

    {sums, counts} =
      Enum.reduce(entries, {sums, counts}, fn %{sampled_at: ts, player_count: count},
                                              {s_acc, c_acc} ->
        if ts <= 0 or ts < earlier_start_ts or ts >= anchor_ts do
          {s_acc, c_acc}
        else
          case find_window(ts, windows) do
            nil ->
              {s_acc, c_acc}

            {window_key, window_start} ->
              slot = div(ts - window_start, 3600)

              if slot < 0 or slot >= hours_per_range do
                {s_acc, c_acc}
              else
                sum_arr = Map.fetch!(s_acc, window_key)
                count_arr = Map.fetch!(c_acc, window_key)

                {
                  Map.put(
                    s_acc,
                    window_key,
                    :array.set(slot, :array.get(slot, sum_arr) + count, sum_arr)
                  ),
                  Map.put(
                    c_acc,
                    window_key,
                    :array.set(slot, :array.get(slot, count_arr) + 1, count_arr)
                  )
                }
              end
          end
        end
      end)

    labels = for i <- 0..(hours_per_range - 1), do: current_start_ts + i * 3600
    restart_ts = Enum.filter(labels, fn ts -> hour_of_day_utc(ts) == 6 end)

    series =
      for key <- ["current", "previous", "earlier"], into: %{} do
        sum_arr = Map.fetch!(sums, key)
        count_arr = Map.fetch!(counts, key)

        line =
          for i <- 0..(hours_per_range - 1) do
            cnt = :array.get(i, count_arr)
            if cnt > 0, do: :array.get(i, sum_arr) / cnt, else: 0.0
          end

        {key, line}
      end

    current_limited = limit_active_hours(series["current"], 150, 4.0)
    active_hours = Enum.count(current_limited, &(&1 > 4.0))

    series =
      series
      |> Map.put("current", current_limited)
      |> Map.update!("current", &smooth_line(&1, 0.35))
      |> Map.update!("previous", &smooth_line(&1, 0.35))
      |> Map.update!("earlier", &smooth_line(&1, 0.35))
      |> shift_comparison_series(hours_per_range)

    compressed = compress_idle_periods(labels, series, 3, 0.01)

    %{
      chart: %{
        "labels" => compressed.labels,
        "current" => compressed.series["current"] || [],
        "previous" => compressed.series["previous"] || [],
        "earlier" => compressed.series["earlier"] || [],
        "restart_ts" => restart_ts
      },
      active_hours: active_hours
    }
  end

  defp build_chart_from_rows(_rows, _now), do: %{chart: empty_chart(), active_hours: 0}

  defp empty_chart,
    do: %{"labels" => [], "current" => [], "previous" => [], "earlier" => [], "restart_ts" => []}

  defp find_window(ts, windows) do
    Enum.find_value(windows, fn {key, %{start: start_ts, end: end_ts}} ->
      if ts >= start_ts and ts < end_ts, do: {key, start_ts}, else: nil
    end)
  end

  defp shift_comparison_series(series, hours_per_range) do
    shift_hours = round(hours_per_range * 0.075)

    if shift_hours > 0 do
      series
      |> Map.update!("previous", &shift_line(&1, shift_hours))
      |> Map.update!("earlier", &shift_line(&1, -shift_hours))
    else
      series
    end
  end

  defp smooth_line(values, blend) when is_list(values) do
    count = length(values)
    blend = max(0.0, min(1.0, blend))

    cond do
      count == 0 ->
        values

      blend <= 0.0 ->
        values

      true ->
        Enum.with_index(values)
        |> Enum.map(fn {current, i} ->
          prev = if i > 0, do: Enum.at(values, i - 1), else: current
          nxt = if i < count - 1, do: Enum.at(values, i + 1), else: current
          neighbor_avg = (prev + nxt) * 0.5
          current * (1.0 - blend) + neighbor_avg * blend
        end)
    end
  end

  defp shift_line(values, 0), do: values

  defp shift_line(values, shift) when is_list(values) do
    count = length(values)

    cond do
      count == 0 ->
        values

      shift > 0 ->
        s = min(shift, count)
        List.duplicate(0.0, s) ++ Enum.take(values, count - s)

      shift < 0 ->
        s = min(abs(shift), count)
        Enum.drop(values, s) ++ List.duplicate(0.0, s)

      true ->
        values
    end
  end

  defp limit_active_hours(values, target_hours, threshold) when is_list(values) do
    above =
      values
      |> Enum.with_index()
      |> Enum.filter(fn {v, _i} -> v > threshold end)

    if length(above) <= target_hours do
      values
    else
      keep =
        above
        |> Enum.sort(fn {va, ia}, {vb, ib} ->
          if va == vb, do: ia <= ib, else: va >= vb
        end)
        |> Enum.take(target_hours)
        |> Enum.map(fn {_v, i} -> i end)
        |> MapSet.new()

      Enum.with_index(values)
      |> Enum.map(fn {v, i} -> if MapSet.member?(keep, i), do: v, else: min(v, threshold) end)
    end
  end

  defp compress_idle_periods(labels, series, chunk_size, threshold) do
    current = Map.get(series, "current", [])
    count = length(labels)

    if count == 0 or chunk_size <= 1 or current == [] do
      %{labels: labels, series: series}
    else
      keys = Map.keys(series)

      {new_labels, new_series} =
        compress_idle_loop(
          labels,
          series,
          keys,
          current,
          count,
          chunk_size,
          threshold,
          0,
          [],
          Map.new(keys, &{&1, []})
        )

      %{
        labels: Enum.reverse(new_labels),
        series: Map.new(new_series, fn {k, v} -> {k, Enum.reverse(v)} end)
      }
    end
  end

  defp compress_idle_loop(
         _labels,
         _series,
         _keys,
         _current,
         count,
         _chunk_size,
         _threshold,
         i,
         acc_labels,
         acc_series
       )
       when i >= count do
    {acc_labels, acc_series}
  end

  defp compress_idle_loop(
         labels,
         series,
         keys,
         current,
         count,
         chunk_size,
         threshold,
         i,
         acc_labels,
         acc_series
       ) do
    value = abs(Enum.at(current, i) || 0.0)

    if value <= threshold do
      run_len = idle_run_length(current, count, i, threshold)

      if run_len < chunk_size do
        {labels2, series2} =
          Enum.reduce(0..(run_len - 1), {acc_labels, acc_series}, fn j, {lacc, sacc} ->
            idx = i + j
            add_point(labels, series, keys, idx, lacc, sacc)
          end)

        compress_idle_loop(
          labels,
          series,
          keys,
          current,
          count,
          chunk_size,
          threshold,
          i + run_len,
          labels2,
          series2
        )
      else
        chunks = max(1, ceil_div(run_len, chunk_size))

        {labels2, series2} =
          Enum.reduce(0..(chunks - 1), {acc_labels, acc_series}, fn chunk, {lacc, sacc} ->
            chunk_start = i + chunk * chunk_size
            chunk_end = min(chunk_start + chunk_size, i + run_len)

            if chunk_start >= i + run_len do
              {lacc, sacc}
            else
              len = max(1, chunk_end - chunk_start)
              lacc2 = [Enum.at(labels, chunk_start) | lacc]

              sacc2 =
                Enum.reduce(keys, sacc, fn key, map_acc ->
                  avg =
                    Enum.reduce(chunk_start..(chunk_end - 1), 0.0, fn idx, sum ->
                      sum + (Enum.at(Map.get(series, key, []), idx) || 0.0)
                    end) / len

                  Map.update!(map_acc, key, &[avg | &1])
                end)

              {lacc2, sacc2}
            end
          end)

        compress_idle_loop(
          labels,
          series,
          keys,
          current,
          count,
          chunk_size,
          threshold,
          i + run_len,
          labels2,
          series2
        )
      end
    else
      {labels2, series2} = add_point(labels, series, keys, i, acc_labels, acc_series)

      compress_idle_loop(
        labels,
        series,
        keys,
        current,
        count,
        chunk_size,
        threshold,
        i + 1,
        labels2,
        series2
      )
    end
  end

  defp add_point(labels, series, keys, idx, acc_labels, acc_series) do
    lacc = [Enum.at(labels, idx) | acc_labels]

    sacc =
      Enum.reduce(keys, acc_series, fn key, map_acc ->
        val = Enum.at(Map.get(series, key, []), idx) || 0.0
        Map.update!(map_acc, key, &[val | &1])
      end)

    {lacc, sacc}
  end

  defp idle_run_length(current, count, start_idx, threshold) do
    Enum.reduce_while(start_idx..(count - 1), 0, fn idx, acc ->
      if abs(Enum.at(current, idx) || 0.0) <= threshold, do: {:cont, acc + 1}, else: {:halt, acc}
    end)
  end

  defp hour_of_day_utc(ts) do
    ts
    |> DateTime.from_unix!()
    |> Map.get(:hour)
  end

  defp ceil_div(a, b), do: div(a + b - 1, b)

  defp fetch_categories([]), do: %{}

  defp fetch_categories(names) do
    Repo.all(from m in MapMeta, where: m.map_name in ^names, select: {m.map_name, m.category})
    |> Map.new()
  end

  defp fetch_meta([]), do: %{}

  defp fetch_meta(names) do
    Repo.all(
      from m in MapMeta,
        where: m.map_name in ^names,
        select: {m.map_name, %{category: m.category, sub_category: m.sub_category}}
    )
    |> Enum.map(fn {name, meta} ->
      {name, %{category: meta.category || "", sub_category: meta.sub_category || ""}}
    end)
    |> Map.new()
  end

  defp build_map_sections(map_names, map_meta) do
    gamemode_set = @page_gamemode_names |> Enum.map(&String.downcase/1) |> MapSet.new()

    {sub_buckets, cat_buckets} =
      Enum.reduce(map_names, {%{}, %{}}, fn map_name, {sub_acc, cat_acc} ->
        lower = String.downcase(map_name)
        meta = Map.get(map_meta, map_name, %{category: "", sub_category: ""})
        category = meta.category || ""
        sub_category = meta.sub_category || ""

        entry = %{
          name: map_name,
          display: map_name,
          type: if(MapSet.member?(gamemode_set, lower), do: "gamemode", else: "map"),
          category: category,
          sub_category: sub_category,
          source: "mapsdb"
        }

        sub_key = String.downcase(sub_category)

        cond do
          sub_key != "" and Map.has_key?(@sub_category_label_map, sub_key) ->
            {Map.update(sub_acc, sub_key, [entry], &[entry | &1]), cat_acc}

          true ->
            bucket_key =
              cond do
                entry.type == "gamemode" and category == "" -> "gamemode"
                category == "" -> "_other"
                true -> String.downcase(category)
              end

            {sub_acc, Map.update(cat_acc, bucket_key, [entry], &[entry | &1])}
        end
      end)

    sub_sections =
      Enum.reduce(@sub_category_order, {[], sub_buckets}, fn sub_key, {acc, buckets} ->
        case Map.pop(buckets, sub_key) do
          {nil, rest} ->
            {acc, rest}

          {entries, rest} ->
            sorted = Enum.sort_by(entries, &String.downcase(&1.name))

            section = %{
              label: @sub_category_label_map[sub_key],
              slug: "subcat-" <> sub_key,
              entries: sorted,
              open: false
            }

            {acc ++ [section], rest}
        end
      end)
      |> then(fn {acc, _rest} -> acc end)

    ordered_cat_sections =
      Enum.reduce(@page_category_order, {[], cat_buckets}, fn cat_key, {acc, buckets} ->
        case Map.pop(buckets, cat_key) do
          {nil, rest} ->
            {acc, rest}

          {entries, rest} ->
            sorted = Enum.sort_by(entries, &String.downcase(&1.name))

            section = %{
              label: format_category_label(cat_key),
              slug: cat_key,
              entries: sorted,
              open: false
            }

            {acc ++ [section], rest}
        end
      end)
      |> then(fn {acc, rest} ->
        extra =
          rest
          |> Enum.sort_by(fn {k, _} -> k end)
          |> Enum.map(fn {bucket_key, entries} ->
            %{
              label: format_category_label(bucket_key),
              slug: bucket_key,
              entries: Enum.sort_by(entries, &String.downcase(&1.name)),
              open: false
            }
          end)

        acc ++ extra
      end)

    sub_sections ++ ordered_cat_sections
  end

  defp maybe_add_server_configs(sections, tf_cfg_dir) do
    entries =
      list_tfcfg_files(
        tf_cfg_dir,
        fn _base, lower ->
          String.contains?(lower, "server") && not String.contains?(lower, "mapcycle")
        end,
        "server",
        "server",
        "tfcfg"
      )

    if entries == [] do
      sections
    else
      sections ++
        [%{label: "Server configs", slug: "server-configs", entries: entries, open: false}]
    end
  end

  defp maybe_add_mapcycles(sections, tf_cfg_dir) do
    entries =
      list_tfcfg_files(
        tf_cfg_dir,
        fn _base, lower -> String.contains?(lower, "mapcycle") end,
        "mapcycle",
        "mapcycle",
        "tfcfg"
      )

    if entries == [] do
      sections
    else
      sections ++ [%{label: "Mapcycles", slug: "mapcycles", entries: entries, open: false}]
    end
  end

  defp add_playercount_settings(sections) do
    sections ++
      [
        %{
          label: "Playercount settings",
          slug: "playercount-settings",
          open: false,
          entries: [
            %{
              name: "d_highpop",
              display: "High Population",
              type: "playercount",
              category: "playercount",
              source: "mapsdb"
            },
            %{
              name: "d_lowpop",
              display: "Low Population",
              type: "playercount",
              category: "playercount",
              source: "mapsdb"
            }
          ]
        }
      ]
  end

  defp maybe_add_category_configs(sections, map_meta) do
    category_targets = [
      {"harvest", :sub_category, "category_harvest", "Harvest-type maps", "subcategory"},
      {"5cp", :category, "category_5cp", "5CP maps", "category"},
      {"3cp", :category, "category_3cp", "3CP maps", "category"},
      {"attack/defend", :category, "category_attack_defend", "Attack/Defend maps", "category"}
    ]

    entries =
      Enum.flat_map(category_targets, fn {slug, column, name, display, type} ->
        exists? =
          Enum.any?(map_meta, fn {_map_name, meta} ->
            val = meta |> Map.get(column, "") |> to_string() |> String.trim() |> String.downcase()
            val == slug
          end)

        if exists? do
          [%{name: name, display: display, type: type, category: type, source: "mapsdb"}]
        else
          []
        end
      end)

    if entries == [] do
      sections
    else
      sections ++
        [%{label: "Category configs", slug: "category-configs", entries: entries, open: false}]
    end
  end

  defp list_tfcfg_files(tf_cfg_dir, predicate, type, category, source) do
    if File.dir?(tf_cfg_dir) do
      tf_cfg_dir
      |> File.ls!()
      |> Enum.filter(fn file ->
        lower = String.downcase(file)
        String.ends_with?(lower, ".cfg") and predicate.(Path.rootname(file), lower)
      end)
      |> Enum.map(fn file ->
        %{
          name: Path.rootname(file),
          display: Path.rootname(file),
          type: type,
          category: category,
          source: source
        }
      end)
      |> Enum.sort_by(&String.downcase(&1.name))
    else
      []
    end
  end

  defp format_category_label(slug) do
    key = String.downcase(to_string(slug || ""))

    cond do
      Map.has_key?(@category_label_map, key) -> @category_label_map[key]
      key in ["", "_other"] -> "Other maps"
      true -> String.upcase(key) <> " maps"
    end
  end

  defp sanitize_source(nil), do: {:ok, "mapsdb"}
  defp sanitize_source("tfcfg"), do: {:ok, "tfcfg"}
  defp sanitize_source(_), do: {:ok, "mapsdb"}

  defp sanitize_map(nil, _source), do: {:error, :missing_map}
  defp sanitize_map("", _source), do: {:error, :missing_map}

  defp sanitize_map(map, source) when is_binary(map) do
    if Regex.match?(~r/^[A-Za-z0-9_]+$/, map) do
      cfg = config()
      base = if source == "tfcfg", do: cfg.tf_cfg_dir, else: cfg.maps_dir
      path = Path.join(base, map <> ".cfg")
      if File.regular?(path), do: {:ok, path, map}, else: {:error, :not_found}
    else
      {:error, :invalid_map}
    end
  end

  defp write_file(path, content) do
    case File.write(path, content) do
      :ok ->
        _ = File.chmod(path, 0o777)
        :ok

      {:error, reason} ->
        {:file_error, reason}
    end
  end

  defp replace_count(contents, search, replace) do
    parts = String.split(contents, search)

    case parts do
      [_single] -> {contents, 0}
      _ -> {Enum.join(parts, replace), length(parts) - 1}
    end
  end

  defp query_rows(sql) do
    case Repo.query(sql) do
      {:ok, %{columns: columns, rows: rows}} ->
        Enum.map(rows, fn row ->
          columns
          |> Enum.zip(row)
          |> Map.new(fn {key, value} -> {String.to_atom(key), value} end)
        end)

      _ ->
        []
    end
  rescue
    _ -> []
  end

  defp table_exists?(table) do
    case Repo.query(
           "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = '#{table}'"
         ) do
      {:ok, %{rows: [[count]]}} -> to_int(count) > 0
      _ -> false
    end
  rescue
    _ -> false
  end

  defp sql_string_list(values) do
    values
    |> Enum.map(fn value -> "'" <> String.replace(to_string(value), "'", "''") <> "'" end)
    |> Enum.join(",")
  end

  defp format_slot(nil), do: "n/a"

  defp format_slot(%{} = row) do
    weekday = row |> Map.get(:weekday) |> to_int()
    hour = row |> Map.get(:hour_of_day) |> to_int()
    "#{weekday_label(weekday)} #{pad2(hour)}:00"
  end

  defp weekday_label(day) do
    Enum.at(~w(Sun Mon Tue Wed Thu Fri Sat), rem(max(day, 0), 7), "n/a")
  end

  defp pad2(value) do
    value
    |> to_int()
    |> Integer.to_string()
    |> String.pad_leading(2, "0")
  end

  defp format_duration(seconds) do
    minutes = max(0, div(seconds, 60))

    cond do
      minutes >= 60 -> "#{div(minutes, 60)}h #{rem(minutes, 60)}m"
      true -> "#{minutes}m"
    end
  end

  defp format_date(0), do: "n/a"

  defp format_date(unix_seconds) do
    unix_seconds
    |> DateTime.from_unix!()
    |> Calendar.strftime("%m/%d %H:%M UTC")
  rescue
    _ -> "n/a"
  end

  defp signed_float(value, decimals) do
    value = to_float(value)
    sign = if value > 0.0, do: "+", else: ""
    sign <> format_float(value, decimals)
  end

  defp format_float(value, decimals) do
    value
    |> to_float()
    |> :erlang.float_to_binary(decimals: decimals)
  end

  defp mtime_unix(%File.Stat{mtime: {{y, mo, d}, {h, mi, s}}}) do
    {:ok, ndt} = NaiveDateTime.new(y, mo, d, h, mi, s)
    DateTime.from_naive!(ndt, "Etc/UTC") |> DateTime.to_unix()
  end

  defp mtime_unix(%File.Stat{}), do: System.system_time(:second)

  defp to_int(v) when is_integer(v), do: v
  defp to_int(v) when is_float(v), do: trunc(v)
  defp to_int(%Decimal{} = v), do: v |> Decimal.to_integer()

  defp to_int(v) when is_binary(v) do
    case Integer.parse(v) do
      {i, _} -> i
      :error -> 0
    end
  end

  defp to_int(_), do: 0

  defp to_float(%Decimal{} = v), do: Decimal.to_float(v)
  defp to_float(v) when is_integer(v), do: v * 1.0
  defp to_float(v) when is_float(v), do: v

  defp to_float(v) when is_binary(v) do
    case Float.parse(v) do
      {f, _} -> f
      :error -> 0.0
    end
  end

  defp to_float(_), do: 0.0

  defp truthy?(v) when v in [true, 1, "1", "true", "yes", "on"], do: true
  defp truthy?(_), do: false
end
