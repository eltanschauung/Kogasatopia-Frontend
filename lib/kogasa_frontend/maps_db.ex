defmodule KogasaFrontend.MapsDb do
  @moduledoc false

  import Ecto.Query

  alias KogasaFrontend.MapsDb.MapMeta
  alias KogasaFrontend.MapsDb.Sections
  alias KogasaFrontend.MapsDb.Source
  alias KogasaFrontend.LegacyPaths
  alias KogasaFrontend.Repo
  alias KogasaFrontend.TimeDisplay
  alias KogasaFrontend.Tf2Classes
  alias KogasaFrontend.WeaponRevertsConfig

  @population_statistics_table "server_population_statistics_samples"
  @map_session_statistics_table "map_statistics_sessions"
  @vote_statistics_table "nativevotes_statistics_events"
  @cwx_weapon_popularity_table "cwx_weapon_popularity"
  @classlimits_statistics_table "classlimits_statistics_events"
  @class_popularity_order [1, 3, 7, 4, 6, 9, 5, 2, 8]

  def config do
    %{
      maps_dir:
        Application.get_env(
          :kogasa_frontend,
          :mapsdb_dir,
          "/home/kogasa/hlserver/tf2/tf/cfg/mapsdb"
        ),
      tf_cfg_dir:
        Application.get_env(
          :kogasa_frontend,
          :mapsdb_tf_cfg_dir,
          "/home/kogasa/hlserver/tf2/tf/cfg"
        ),
      preview_dir:
        Application.get_env(
          :kogasa_frontend,
          :mapsdb_preview_dir,
          LegacyPaths.playercount_widget_dir()
        )
    }
  end

  def page_data do
    cfg = config()
    maps_dir_missing = not File.dir?(cfg.maps_dir)
    chart_bundle = popularity_chart_bundle()

    %{
      maps_dir: cfg.maps_dir,
      maps_dir_missing: maps_dir_missing,
      popular_maps: fetch_map_popularity(25),
      popularity_chart: chart_bundle.chart,
      popularity_active_hours: chart_bundle.active_hours,
      map_analytics: map_detail_analytics(),
      map_previews: map_previews(cfg.preview_dir),
      map_sections: if(maps_dir_missing, do: [], else: build_page_sections(cfg))
    }
  end

  def list_api_maps do
    cfg = config()
    files = Path.wildcard(Path.join(cfg.maps_dir, "*.cfg"))

    rows =
      files
      |> Enum.filter(&File.regular?/1)
      |> Enum.filter(&multi_line_config?/1)
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
    Sections.order_api_rows(rows, categories)
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

  def build_page_sections(cfg \\ config()) do
    maps_dir = cfg.maps_dir
    tf_cfg_dir = cfg.tf_cfg_dir

    map_names =
      Path.wildcard(Path.join(maps_dir, "*.cfg"))
      |> Enum.filter(&File.regular?/1)
      |> Enum.filter(&multi_line_config?/1)
      |> Enum.map(&Path.rootname(Path.basename(&1)))
      |> Enum.sort_by(&String.downcase/1)

    map_meta = fetch_meta(map_names)

    sections =
      []
      |> maybe_add_server_configs(tf_cfg_dir)
      |> maybe_add_mapcycles(tf_cfg_dir)
      |> add_playercount_settings()
      |> maybe_add_category_configs(map_meta)

    map_sections = Sections.build_map_sections(map_names, map_meta)
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

  def active_hours_last_days(days \\ 30) do
    days = days |> to_int() |> max(1) |> min(366)

    case query_rows("""
         SELECT UNIX_TIMESTAMP(DATE_SUB(NOW(), INTERVAL #{days} DAY)) AS start_ts,
                UNIX_TIMESTAMP(NOW()) AS end_ts
         """) do
      [%{start_ts: start_ts, end_ts: end_ts}] -> active_hours_between(start_ts, end_ts)
      _ -> 0
    end
  end

  def active_hours_between(start_ts, end_ts) do
    start_ts = to_int(start_ts)
    end_ts = to_int(end_ts)

    if start_ts <= 0 or end_ts <= start_ts do
      0
    else
      sql = """
      SELECT COUNT(*) AS active_hours
      FROM (
        SELECT FLOOR(sampled_at / 3600) AS hour_bucket
        FROM mapsdb_popularity_log
        WHERE sampled_at >= ?
          AND sampled_at < ?
          AND player_count > 2
          AND map_name NOT LIKE 'mge\\\\_%' ESCAPE '\\\\'
        GROUP BY hour_bucket
      ) active_hour_buckets
      """

      case Repo.query(sql, [start_ts, end_ts]) do
        {:ok, %{rows: [[active_hours]]}} -> to_int(active_hours)
        _ -> 0
      end
    end
  rescue
    _ -> 0
  end

  def map_detail_analytics do
    rows = fetch_map_detail_rows(40)

    %{
      rows: rows,
      top_sessions: fetch_session_extremes(:top, 8),
      worst_sessions: fetch_session_extremes(:worst, 8),
      weekday_hours: fetch_weekday_hour_performance(12),
      class_popularity: fetch_class_popularity(),
      popular_custom_weapons: fetch_popular_custom_weapons(),
      best_performing_chart: rows |> Enum.take(15) |> fetch_map_lifecycle_chart(10),
      vote_table_available: table_exists?(@vote_statistics_table)
    }
  end

  defp fetch_map_detail_rows(limit) do
    lim = max(1, min(limit, 100))

    sessions =
      query_rows("""
      SELECT s.map_name,
             MIN(s.gamemode) AS gamemode,
             COUNT(*) AS sessions,
             ROUND(AVG(s.avg_players), 2) AS avg_players,
             MAX(s.peak_players) AS peak_players,
             ROUND(SUM(s.player_seconds) / 3600, 1) AS player_hours,
             SUM(s.joins) AS joins,
             SUM(s.leaves) AS leaves
      FROM #{@map_session_statistics_table} s
      WHERE #{valid_map_session_sql("s")}
      GROUP BY s.map_name
      ORDER BY player_hours DESC, avg_players DESC
      LIMIT #{lim}
      """)

    first15 =
      query_rows("""
      SELECT p.map_name,
             ROUND(AVG(CASE WHEN p.map_elapsed_seconds BETWEEN 0 AND 899 THEN p.player_count END), 2) AS first15_avg,
             ROUND(
               COALESCE(AVG(CASE WHEN p.map_elapsed_seconds BETWEEN 600 AND 899 THEN p.player_count END), 0) -
               COALESCE(AVG(CASE WHEN p.map_elapsed_seconds BETWEEN 0 AND 299 THEN p.player_count END), 0),
               2
             ) AS first15_growth
      FROM #{@population_statistics_table} p
      JOIN #{@map_session_statistics_table} s
        ON s.host_port = p.host_port
       AND s.map_session_id = p.map_session_id
       AND s.map_name = p.map_name
      WHERE p.map_elapsed_seconds BETWEEN 0 AND 899
        AND #{valid_map_session_sql("s")}
        AND #{valid_population_sample_sql("p", "s")}
      GROUP BY p.map_name
      """)
      |> Map.new(fn row -> {row.map_name, row} end)

    best_slots =
      query_rows("""
      SELECT s.map_name,
             s.weekday,
             s.hour_of_day,
             COUNT(*) AS sessions,
             ROUND(AVG(s.avg_players), 2) AS avg_players
      FROM #{@map_session_statistics_table} s
      WHERE #{valid_map_session_sql("s")}
      GROUP BY s.map_name, s.weekday, s.hour_of_day
      ORDER BY s.map_name ASC, avg_players DESC, sessions DESC
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
        vote_wins: to_int(Map.get(votes, :vote_wins))
      }
    end)
  end

  defp fetch_session_extremes(:worst, limit) do
    lim = max(1, min(limit, 25))

    query_rows("""
    SELECT s.map_name,
           s.map_session_id,
           s.started_at,
           s.duration,
           MAX(p.player_count) AS peak_players,
           ROUND(AVG(p.player_count), 2) AS avg_players,
           SUM(p.player_seconds_delta) AS player_seconds,
           SUM(p.joining_players) AS joins,
           SUM(p.leaving_players) AS leaves,
           s.end_reason
    FROM #{@map_session_statistics_table} s
    JOIN #{@population_statistics_table} p
      ON p.host_port = s.host_port
     AND p.map_session_id = s.map_session_id
     AND p.map_name = s.map_name
    WHERE #{valid_map_session_sql("s")}
      AND s.start_players >= 10
      AND #{valid_population_sample_sql("p", "s")}
      AND p.player_count > 3
      AND FLOOR(MOD(p.sampled_at, 86400) / 3600) >= 2
      AND FLOOR(MOD(p.sampled_at, 86400) / 3600) < 5
    GROUP BY s.host_port, s.map_session_id, s.map_name, s.started_at, s.duration, s.end_reason
    HAVING peak_players > 4
    ORDER BY avg_players ASC, peak_players ASC, duration DESC
    LIMIT #{lim}
    """)
    |> format_session_extreme_rows()
  end

  defp fetch_session_extremes(_kind, limit) do
    lim = max(1, min(limit, 25))

    query_rows("""
    SELECT s.map_name,
           s.map_session_id,
           s.started_at,
           s.duration,
           s.peak_players,
           s.avg_players,
           s.player_seconds,
           s.joins,
           s.leaves,
           s.end_reason
    FROM #{@map_session_statistics_table} s
    WHERE #{valid_map_session_sql("s")}
    ORDER BY s.avg_players DESC, s.peak_players DESC, s.duration DESC
    LIMIT #{lim}
    """)
    |> format_session_extreme_rows()
  end

  defp format_session_extreme_rows(rows) do
    rows
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
    SELECT s.weekday,
           s.hour_of_day,
           COUNT(*) AS sessions,
           ROUND(AVG(s.avg_players), 2) AS avg_players,
           MAX(s.peak_players) AS peak_players,
           ROUND(SUM(s.player_seconds) / 3600, 1) AS player_hours
    FROM #{@map_session_statistics_table} s
    WHERE #{valid_map_session_sql("s")}
    GROUP BY s.weekday, s.hour_of_day
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

  defp fetch_class_popularity do
    if table_exists?(@classlimits_statistics_table) do
      counts =
        query_rows("""
        SELECT CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(message, 'class=', -1), '|', 1) AS UNSIGNED) AS class_id,
               COUNT(*) AS samples
        FROM #{@classlimits_statistics_table}
        WHERE event_name = 'class_snapshot'
          AND message LIKE '%|class=%'
        GROUP BY class_id
        """)
        |> Map.new(fn row -> {to_int(row.class_id), to_int(row.samples)} end)

      total =
        @class_popularity_order
        |> Enum.map(&Map.get(counts, &1, 0))
        |> Enum.sum()

      Enum.map(@class_popularity_order, fn class_id ->
        samples = Map.get(counts, class_id, 0)
        percentage = if total > 0, do: samples / total * 100.0, else: 0.0
        {:ok, {label, icon}} = Tf2Classes.leaderboard_icon_for_id(class_id)

        %{
          class_id: class_id,
          label: label,
          icon: icon,
          samples: samples,
          percentage: percentage,
          percentage_display: format_float(percentage, 1) <> "%",
          bar_width: format_float(percentage, 4) <> "%"
        }
      end)
    else
      []
    end
  end

  defp fetch_popular_custom_weapons do
    if table_exists?(@cwx_weapon_popularity_table) do
      cwx_names = WeaponRevertsConfig.cwx_item_names()

      query_rows("""
      SELECT weapon_uid,
             COUNT(DISTINCT steamid64) AS equipped_clients
      FROM #{@cwx_weapon_popularity_table}
      WHERE equipped != 0
        AND weapon_uid <> ''
      GROUP BY weapon_uid
      HAVING equipped_clients > 1
      ORDER BY equipped_clients DESC, weapon_uid ASC
      """)
      |> Enum.map(fn row ->
        weapon_uid = to_string(row.weapon_uid || "")

        %{
          weapon_uid: weapon_uid,
          name: Map.get(cwx_names, weapon_uid, weapon_uid),
          equipped_clients: to_int(row.equipped_clients)
        }
      end)
    else
      []
    end
  end

  defp fetch_map_lifecycle_chart(rows, bucket_count) do
    map_names =
      rows
      |> Enum.map(& &1.map_name)
      |> Enum.reject(&(&1 == ""))
      |> Enum.take(15)

    bucket_count = max(1, min(bucket_count, 20))
    common_seconds = fetch_common_lifecycle_seconds(map_names)
    labels = lifecycle_chart_labels(bucket_count, common_seconds)

    if map_names == [] or common_seconds <= 0 do
      %{"labels" => labels, "series" => []}
    else
      rows =
        query_rows("""
        SELECT p.map_name,
               LEAST(#{bucket_count - 1}, FLOOR((p.map_elapsed_seconds * #{bucket_count}) / #{common_seconds})) AS bucket,
               ROUND(AVG(CASE WHEN p.player_count > 23 THEN 24 ELSE p.player_count END), 2) AS avg_players
        FROM #{@population_statistics_table} p
        JOIN #{@map_session_statistics_table} s
          ON s.host_port = p.host_port
         AND s.map_session_id = p.map_session_id
         AND s.map_name = p.map_name
        WHERE p.map_name IN (#{sql_string_list(map_names)})
          AND p.map_elapsed_seconds >= 0
          AND p.map_elapsed_seconds <= #{common_seconds}
          AND #{valid_map_session_sql("s")}
          AND #{valid_population_sample_sql("p", "s")}
        GROUP BY p.map_name, bucket
        ORDER BY p.map_name ASC, bucket ASC
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
              values
              |> Map.get(map_name, %{})
              |> lifecycle_chart_data(bucket_count)
          }
        end)

      %{"labels" => labels, "series" => series}
    end
  end

  defp fetch_common_lifecycle_seconds([]), do: 0

  defp fetch_common_lifecycle_seconds(map_names) do
    query_rows("""
    SELECT MIN(map_max_elapsed) AS common_seconds
    FROM (
      SELECT p.map_name,
             MAX(LEAST(p.map_elapsed_seconds, s.duration)) AS map_max_elapsed
      FROM #{@population_statistics_table} p
      JOIN #{@map_session_statistics_table} s
        ON s.host_port = p.host_port
       AND s.map_session_id = p.map_session_id
       AND s.map_name = p.map_name
      WHERE p.map_name IN (#{sql_string_list(map_names)})
        AND p.map_elapsed_seconds >= 0
        AND #{valid_map_session_sql("s")}
        AND #{valid_population_sample_sql("p", "s")}
      GROUP BY p.map_name
    ) map_ends
    """)
    |> case do
      [%{common_seconds: seconds}] -> to_int(seconds)
      _ -> 0
    end
  end

  defp lifecycle_chart_data(point_map, bucket_count) do
    values = for bucket <- 0..(bucket_count - 1), do: Map.get(point_map, bucket)
    first_value = Enum.find(values, &(!is_nil(&1)))

    values
    |> Enum.map_reduce(first_value, fn
      nil, last_value -> {last_value, last_value}
      value, _last_value -> {value, value}
    end)
    |> elem(0)
  end

  defp lifecycle_chart_labels(bucket_count, common_seconds) do
    for bucket <- 0..(bucket_count - 1) do
      cond do
        bucket == 0 ->
          "Start"

        bucket == bucket_count - 1 ->
          "End"

        common_seconds > 0 ->
          minutes = round(bucket * common_seconds / max(bucket_count - 1, 1) / 60)
          "#{minutes}m"

        true ->
          "#{div(bucket * 100, bucket_count)}%"
      end
    end
  end

  defp fetch_vote_pressure do
    if table_exists?(@vote_statistics_table) do
      query_rows("""
      SELECT map_name,
             SUM(event_type = 'nomination') AS nominations,
             SUM(event_type = 'rtv') AS rtvs,
             SUM(event_type = 'vote_option') AS vote_options,
             SUM(event_type = 'vote_winner') AS vote_wins
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
    active_hours = active_hours_last_days(30)

    sql = """
    SELECT sampled_at, player_count
    FROM mapsdb_popularity_log
    WHERE sampled_at >= UNIX_TIMESTAMP(DATE_SUB(NOW(), INTERVAL 90 DAY))
      AND map_name NOT LIKE 'mge\\\\_%' ESCAPE '\\\\'
    ORDER BY sampled_at ASC
    """

    with {:ok, %{rows: rows}} <- Repo.query(sql) do
      rows
      |> build_chart_from_rows(now)
      |> Map.put(:active_hours, active_hours)
    else
      _ -> %{chart: empty_chart(), active_hours: active_hours}
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
    restart_ts = Enum.filter(labels, fn ts -> TimeDisplay.server_hour(ts) == 6 end)

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

    series =
      series
      |> Map.update!("current", &smooth_line(&1, 0.35))
      |> Map.update!("previous", &smooth_line(&1, 0.35))
      |> Map.update!("earlier", &smooth_line(&1, 0.35))
      |> shift_comparison_series(hours_per_range)

    compressed = compress_idle_periods(labels, series, 3, 0.01, MapSet.new(restart_ts))

    %{
      chart: %{
        "labels" => compressed.labels,
        "current" => compressed.series["current"] || [],
        "previous" => compressed.series["previous"] || [],
        "earlier" => compressed.series["earlier"] || [],
        "restart_ts" => restart_ts
      },
      active_hours: 0
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

  defp compress_idle_periods(
         labels,
         series,
         chunk_size,
         threshold,
         preserve_timestamps
       ) do
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
          preserve_timestamps,
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
         _preserve_timestamps,
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
         preserve_timestamps,
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
          preserve_timestamps,
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

              label_idx =
                preserved_label_index(labels, chunk_start, chunk_end, preserve_timestamps)

              lacc2 = [Enum.at(labels, label_idx || chunk_start) | lacc]

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
          preserve_timestamps,
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
        preserve_timestamps,
        i + 1,
        labels2,
        series2
      )
    end
  end

  defp preserved_label_index(labels, chunk_start, chunk_end, preserve_timestamps) do
    Enum.find(chunk_start..(chunk_end - 1), fn idx ->
      MapSet.member?(preserve_timestamps, Enum.at(labels, idx))
    end)
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
    entries =
      [
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
      |> Enum.filter(&mapsdb_entry_has_multiple_lines?/1)

    if entries == [] do
      sections
    else
      sections ++
        [
          %{
            label: "Playercount settings",
            slug: "playercount-settings",
            open: false,
            entries: entries
          }
        ]
    end
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

        entry = %{name: name, display: display, type: type, category: type, source: "mapsdb"}

        if exists? and mapsdb_entry_has_multiple_lines?(entry) do
          [entry]
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
        path = Path.join(tf_cfg_dir, file)

        String.ends_with?(lower, ".cfg") and predicate.(Path.rootname(file), lower) and
          multi_line_config?(path)
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

  defp sanitize_source(source), do: Source.sanitize(source)

  defp sanitize_map(nil, _source), do: {:error, :missing_map}
  defp sanitize_map("", _source), do: {:error, :missing_map}

  defp sanitize_map(map, source) when is_binary(map) do
    if Regex.match?(~r/^[A-Za-z0-9_]+$/, map) do
      cfg = config()
      base = if source == "tfcfg", do: cfg.tf_cfg_dir, else: cfg.maps_dir
      path = Path.join(base, map <> ".cfg")

      with true <- allowed_config?(map, source, cfg),
           true <- File.regular?(path),
           {:ok, safe_path} <- contained_path(path, base) do
        {:ok, safe_path, map}
      else
        _ -> {:error, :not_found}
      end
    else
      {:error, :invalid_map}
    end
  end

  defp allowed_config?(map, "tfcfg", cfg) do
    cfg.tf_cfg_dir
    |> allowed_tfcfg_entries()
    |> MapSet.member?(map)
  end

  defp allowed_config?(map, _source, cfg) do
    cfg.maps_dir
    |> allowed_mapsdb_entries()
    |> MapSet.member?(map)
  end

  defp allowed_mapsdb_entries(maps_dir) do
    maps_dir
    |> wildcard_cfg_names()
    |> MapSet.new()
  end

  defp allowed_tfcfg_entries(tf_cfg_dir) do
    server_configs =
      list_tfcfg_files(
        tf_cfg_dir,
        fn _base, lower ->
          String.contains?(lower, "server") && not String.contains?(lower, "mapcycle")
        end,
        "server",
        "server",
        "tfcfg"
      )

    mapcycles =
      list_tfcfg_files(
        tf_cfg_dir,
        fn _base, lower -> String.contains?(lower, "mapcycle") end,
        "mapcycle",
        "mapcycle",
        "tfcfg"
      )

    (server_configs ++ mapcycles)
    |> Enum.map(& &1.name)
    |> MapSet.new()
  end

  defp wildcard_cfg_names(dir) do
    dir
    |> Path.join("*.cfg")
    |> Path.wildcard()
    |> Enum.filter(&File.regular?/1)
    |> Enum.filter(&multi_line_config?/1)
    |> Enum.map(&Path.rootname(Path.basename(&1)))
  end

  defp mapsdb_entry_has_multiple_lines?(%{name: name}) do
    config().maps_dir
    |> Path.join(name <> ".cfg")
    |> multi_line_config?()
  end

  defp multi_line_config?(path) do
    path
    |> File.stream!([], :line)
    |> Enum.take(2)
    |> length()
    |> Kernel.>(1)
  rescue
    _ -> false
  end

  defp contained_path(path, base) do
    base_path = Path.expand(base)
    safe_path = Path.expand(path)

    with {:ok, %File.Stat{type: type}} when type != :symlink <- File.lstat(path) do
      if safe_path == base_path or String.starts_with?(safe_path, base_path <> "/") do
        {:ok, safe_path}
      else
        {:error, :not_found}
      end
    else
      _ -> {:error, :not_found}
    end
  end

  defp valid_map_session_sql(alias_name) do
    """
    #{alias_name}.peak_players >= 8
    AND #{alias_name}.duration >= 600
    AND #{alias_name}.end_reason IN ('map_end', 'historical', 'synthetic_backfill')
    """
  end

  defp valid_population_sample_sql(sample_alias, session_alias) do
    """
    #{sample_alias}.player_count > 0
    AND #{sample_alias}.player_count <= 32
    AND #{sample_alias}.sampled_at BETWEEN #{session_alias}.started_at AND #{session_alias}.ended_at + 120
    AND #{sample_alias}.map_elapsed_seconds BETWEEN 0 AND #{session_alias}.duration + 120
    """
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

  defp sql_string(value), do: "'" <> String.replace(to_string(value), "'", "''") <> "'"

  defp sql_string_list(values) do
    values
    |> Enum.map(&sql_string/1)
    |> Enum.join(",")
  end

  defp format_slot(nil), do: "n/a"

  defp format_slot(%{} = row) do
    weekday = row |> Map.get(:weekday) |> to_int()
    hour = row |> Map.get(:hour_of_day) |> to_int()
    "#{weekday_label(weekday)} #{pad2(hour)}:00 ET"
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
    TimeDisplay.format_server_datetime(unix_seconds)
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
    TimeDisplay.server_naive_to_unix(ndt)
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
end
