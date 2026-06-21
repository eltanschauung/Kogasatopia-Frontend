defmodule KogasaFrontend.PlayercountWidget do
  @moduledoc false

  alias KogasaFrontend.LegacyPaths
  alias KogasaFrontend.Tf2Classes

  @public_ip "173.255.237.230"
  @flag_base "https://bantculture.com/static/flags"

  @important_map_names ~w(
    touh manj offblast_pro product_pro genbu bant candid forest_of_magic chireiden
    dm_sdm mge eien nagae circu heaven haku hakurei dustbowl_pro brawl letty
    d_pro dom_h rokk gasa ard_event
  )

  def render(:index), do: render_main_widget()

  def render(:index2),
    do: "File not found: http://185.127.19.83/tf2stats/quickstats.txt" <> player_style() <> "\n"

  def render(:index3),
    do:
      render_player_widget(
        "server27016_quickstats.txt",
        @public_ip,
        [{"United States", "us"}, {"Goku", "goku"}, {"Kaguya", "kaguya"}],
        true,
        false
      )

  def render(:index4),
    do:
      render_player_widget(
        "server4_quickstats.txt",
        "",
        [{"United States", "us"}, {"Cirno", "cirno"}, {"Daiyousei", "daiyousei"}],
        false,
        true
      ) <> "\n"

  defp render_main_widget do
    file = "quickstats.txt"

    case read_lines(file) do
      {:ok, lines} ->
        stats = parse_stats(lines, trim_lines?: false)
        server_name = main_server_name(stats.server_name)
        map_name = stats.map_name
        map_image = map_image(map_name, false)

        [
          ~s(<div class="server-name">#{server_name}</div>),
          "<hr>",
          ~s(<div class="server-ip"><a href="steam://connect/#{@public_ip}:#{stats.port}">#{@public_ip}:#{stats.port}</a> ),
          flag_img("United States", "us"),
          flag_img("Kogasa", "kogasa"),
          "</div>",
          ~s(<div class="info-container"><div class="label">Otter Population:</div><div class="value">#{stats.player_count}</div></div>),
          ~s(<div class="info-container"><div class="label">Map:</div>),
          main_map_value(map_name),
          "</div>",
          ~s|<div class="image-container"><div style="display: flex; justify-content: center;padding:0.2em;"><div id="mapImage" style="background-image: url(placeholder.jpg);"><img src="#{map_image}" alt=""></div></div></div>|,
          "<hr>",
          main_map_stats_html(),
          ~s(<div class="flex-container"><a href="/online" target="_blank"><img src="whaletracker_footer.png" alt="whaley"></a><img src="kogalog.gif" alt="koggyspin" title="It's up." /></div>),
          main_style()
        ]
        |> IO.iodata_to_binary()

      :error ->
        "File not found: #{file}" <> main_style()
    end
  end

  defp render_player_widget(file, server_ip, flags, include_nue?, unknown_fallback?) do
    case read_lines(file) do
      {:ok, lines} ->
        stats = parse_stats(lines, trim_lines?: true)
        map_image = map_image(stats.map_name, unknown_fallback?)

        [
          ~s(<div class="server-name">#{stats.server_name}</div>),
          "<hr>",
          ~s(<div class="server-ip"><a href="steam://connect/#{server_ip}:#{stats.port}">#{server_ip}:#{stats.port} </a>),
          Enum.map(flags, fn {title, code} -> flag_img(title, code) end),
          "</div>",
          ~s(<div class="info-container"><div class="label">Otter Population:</div><div class="value">#{stats.player_count}</div></div>),
          ~s(<div class="info-container"><div class="label">Map:</div><div class="value">#{stats.map_name}</div></div>),
          ~s(<div class="image-container"><div style="display: flex; justify-content: center;padding:0.2em;"><img style="border: 0.1em solid grey; "src="#{map_image}" alt=""></div></div>),
          "<hr>",
          player_list_html(stats.players),
          if(include_nue?,
            do:
              ~s(<img src="nue_ufo.gif" alt="nuefly" style="max-height:6em;margin-bottom:-1em;float:right;" title="It's up." />),
            else: ""
          ),
          player_style()
        ]
        |> IO.iodata_to_binary()

      :error ->
        "File not found: #{file}\n" <> player_style()
    end
  end

  defp parse_stats(lines, opts) do
    parsed_lines =
      if Keyword.get(opts, :trim_lines?, false) do
        lines |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))
      else
        lines
      end

    Enum.reduce(
      parsed_lines,
      %{server_name: "", port: "", player_count: "", map_name: "", players: []},
      fn line, acc ->
        cond do
          String.starts_with?(line, "Hostname:") ->
            %{acc | server_name: line |> String.replace_prefix("Hostname:", "") |> String.trim()}

          String.starts_with?(line, "Port:") ->
            %{acc | port: line |> String.replace_prefix("Port:", "") |> String.trim()}

          String.starts_with?(line, "Player Count:") ->
            %{
              acc
              | player_count: line |> String.replace_prefix("Player Count:", "") |> String.trim()
            }

          String.starts_with?(line, "Map Name:") ->
            map_name =
              line
              |> String.replace_prefix("Map Name:", "")
              |> String.split(".")
              |> List.first()

            %{acc | map_name: map_name || ""}

          Regex.match?(~r/^Player \d+: (.+)$/, line) ->
            [_, player] = Regex.run(~r/^Player \d+: (.+)$/, line)
            %{acc | players: acc.players ++ [player]}

          true ->
            acc
        end
      end
    )
  end

  defp main_map_value(map_name) do
    if important_map?(map_name) do
      ~s(<div class="value3"><img src="chaos_emerald_green.png" title="Important Map" style="margin-right:0px;">#{map_name}</div>)
    else
      ~s(<div class="value">#{map_name}</div>)
    end
  end

  defp main_server_name(server_name) do
    server_name
    |> to_string()
    |> String.split("|")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.take(2)
    |> case do
      [] -> "kogasa.tf | New Jersey"
      parts -> Enum.join(parts, " | ")
    end
  end

  defp main_map_stats_html do
    lines =
      case read_lines("mapstats_output.txt") do
        {:ok, lines} ->
          lines |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == "")) |> Enum.take(8)

        :error ->
          []
      end

    items =
      Enum.map(lines, fn line ->
        if important_map?(line) do
          ~s(<li><img src="chaos_emerald_green.png" title="Important Map">#{html_escape(line)}</li>)
        else
          ~s(<li>#{html_escape(line)}</li>)
        end
      end)

    [
      ~s(<div class="data-list" style="background-color:#1a1815;"><div class="label">Whale schools:</div><div class="value2"><ol>),
      items,
      "</ol></div></div><br>"
    ]
  end

  defp player_list_html(players) do
    rows =
      Enum.map(players, fn player_data ->
        parts = String.split(player_data, "[X]")
        name = Enum.at(parts, 0, "")
        class = Enum.at(parts, 1, "")

        [
          "<li>",
          name,
          " ",
          class_icon_html(class),
          "</li>"
        ]
      end)

    [
      ~s(<div class="players-list" style="background-color: #1a1815;"><div class="label">Otters:</div>),
      rows,
      "</ul></div></div><br>",
      "</div><br>"
    ]
  end

  defp class_icon_html(class) do
    case Tf2Classes.leaderboard_icon_for_label(class) do
      {:ok, {_label, image}} -> ~s(<img src="#{image}" alt="#{image}" title="#{image}  "> )
      :error -> ""
    end
  end

  defp important_map?(value) do
    value = to_string(value)
    Enum.any?(@important_map_names, &String.contains?(value, &1))
  end

  defp map_image(map_name, unknown_fallback?) do
    local = "#{map_name}.jpg"

    cond do
      File.exists?(Path.join(root(), local)) -> local
      unknown_fallback? -> "unknown.jpg"
      true -> "https://image.gametracker.com/images/maps/160x120/tf2/#{map_name}.jpg"
    end
  end

  defp flag_img(title, code), do: ~s(<img title="#{title}" src="#{@flag_base}/#{code}.png">)

  defp read_lines(file) do
    file
    |> quickstats_paths()
    |> Enum.find(&File.exists?/1)
    |> case do
      nil ->
        :error

      path ->
        {:ok,
         path |> File.read!() |> String.split(~r/\R/, trim: false) |> drop_final_empty_line()}
    end
  end

  defp quickstats_paths(file) do
    [
      Path.join(LegacyPaths.quickstats_dir(), file),
      Path.join(root(), file)
    ]
    |> Enum.uniq()
  end

  defp drop_final_empty_line(lines) do
    case Enum.reverse(lines) do
      ["" | rest] -> Enum.reverse(rest)
      _ -> lines
    end
  end

  defp root do
    LegacyPaths.playercount_widget_dir()
  end

  defp html_escape(value) do
    value
    |> to_string()
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
  end

  defp main_style do
    """

    <style>
        body {
          font-family: Open Sans,Helvetica Neue,Helvetica,Arial,sans-serif;
          line-height: 1.2em;
          color: white;
          background-color:#3d3730;
        }

        .server-name {
          font-size: 0.9em;
          font-weight: bold;
        }

        a {
          text-decoration: none;
          color: #ee6c3b;
          font-size: 1em;
        }

        .info-container {
          display: flex;
          justify-content: space-between;
          margin-bottom: 5px;
        }

            .flex-container {
                display: flex;
                justify-content: space-between;
                align-items: flex-end;
            }

            .flex-container img {
                max-height: 4em;
            }

        .label {
          flex: 1;
          font-weight: bold;
          font-size: 0.85em;
          color: white;
        }

        .value {
          flex: 1;
          text-align: right;
          color: white;
        }
        .value2 {
          text-align: center;
          flex: 1;
          color: white;
        }
        .data-list {
          font-size: 0.9em;
          border: 0.2em solid grey;
        }
        .server-ip img {
          padding: 1px;
        }
        #mapImage {
          width: 160px;
          height: 120px;
          border: 0.1em solid grey
        }
      }

    </style>
    """
  end

  defp player_style do
    """

    <style>
        body {
          font-family: Open Sans,Helvetica Neue,Helvetica,Arial,sans-serif;
          line-height: 1.2em;
          color: white;
          background: #3d3730;
        }

        .server-name {
          font-size: 0.9em;
          font-weight: bold;
        }

        a {
          text-decoration: none;
          color: #ee6c3b;
          font-size: 1em;
        }

        .info-container {
          display: flex;
          justify-content: space-between;
          margin-bottom: 5px;
        }

         .flex-container {
          display: flex;
          justify-content: space-between;
          align-items: flex-end;
        }

        .label {
          flex: 1;
          font-weight: bold;
          font-size: 0.85em;
          color: white;
        }

        .value {
          flex: 1;
          color: white;
        }
        .value2 {
          flex: 1;
          color: white;
        }
        li {
          margin-bottom: 4px;
          list-style-type: none;
        }
        .players-list {
          padding: 0.5em;
          font-size: 0.9em;
          border: 0.2em solid grey;
        }
        .server-ip img {
          padding: 1px;
        }
      }

    </style>
    """
  end
end
