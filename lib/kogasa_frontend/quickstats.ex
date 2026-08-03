defmodule KogasaFrontend.Quickstats do
  @moduledoc false

  import KogasaFrontend.Value, only: [int: 1]

  alias KogasaFrontend.LegacyPaths

  @files_by_port %{
    27_015 => "quickstats.txt",
    27_016 => "server27016_quickstats.txt",
    27_018 => "server4_quickstats.txt"
  }

  def file_for_port(port), do: Map.get(@files_by_port, int(port))

  def hostname_for_port(port, fallback \\ "") do
    case file_for_port(port) do
      nil ->
        fallback

      file ->
        case read(file) do
          {:ok, %{server_name: server_name}} -> compact_hostname(server_name, fallback)
          :error -> fallback
        end
    end
  end

  def compact_hostname(value, fallback \\ "") do
    value
    |> to_string()
    |> String.split("|")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.take(2)
    |> case do
      [] -> fallback
      parts -> Enum.join(parts, " | ")
    end
  end

  def read(file, opts \\ []) do
    with {:ok, lines} <- read_lines(file) do
      {:ok, parse_lines(lines, opts)}
    end
  end

  def read_lines(file) do
    file
    |> paths()
    |> Enum.find(&File.exists?/1)
    |> case do
      nil ->
        :error

      path ->
        lines =
          path
          |> File.read!()
          |> String.split(~r/\R/, trim: false)
          |> drop_final_empty_line()

        {:ok, lines}
    end
  rescue
    _ -> :error
  end

  def parse_lines(lines, opts \\ []) do
    lines =
      if Keyword.get(opts, :trim_lines?, false) do
        lines |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))
      else
        lines
      end

    Enum.reduce(
      lines,
      %{server_name: "", port: "", player_count: "", map_name: "", players: []},
      &parse_line/2
    )
  end

  def paths(file) do
    [
      Path.join(LegacyPaths.quickstats_dir(), file),
      Path.join(LegacyPaths.playercount_widget_dir(), file)
    ]
    |> Enum.uniq()
  end

  defp parse_line(line, acc) do
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
          |> String.trim()
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

  defp drop_final_empty_line(lines) do
    case Enum.reverse(lines) do
      ["" | rest] -> Enum.reverse(rest)
      _ -> lines
    end
  end
end
