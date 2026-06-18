defmodule KogasaFrontend.CountryNames do
  @moduledoc false

  @default_iso3166_tab_path "/usr/share/zoneinfo/iso3166.tab"
  @cache_key {__MODULE__, :iso3166_names}

  def metadata(code) do
    case normalize_code(code) do
      "" -> nil
      normalized -> %{code: normalized, name: display_name(normalized)}
    end
  end

  def display_name(code) do
    case normalize_code(code) do
      "" -> ""
      normalized -> Map.get(country_names(), String.upcase(normalized), String.upcase(normalized))
    end
  end

  def normalize_code(code) do
    code
    |> to_string_or_empty()
    |> String.trim()
    |> String.downcase()
  end

  defp country_names do
    :persistent_term.get(@cache_key, nil) || load_country_names()
  end

  defp load_country_names do
    names =
      iso3166_tab_path()
      |> File.read()
      |> case do
        {:ok, contents} -> parse_iso3166_tab(contents)
        _ -> %{}
      end

    :persistent_term.put(@cache_key, names)
    names
  end

  defp iso3166_tab_path do
    Application.get_env(:kogasa_frontend, :iso3166_tab_path, @default_iso3166_tab_path)
  end

  defp parse_iso3166_tab(contents) do
    contents
    |> String.split("\n")
    |> Enum.reduce(%{}, fn line, acc ->
      line = String.trim(line)

      cond do
        line == "" or String.starts_with?(line, "#") ->
          acc

        true ->
          case String.split(line, "\t", parts: 2) do
            [code, name] -> Map.put(acc, String.upcase(String.trim(code)), String.trim(name))
            _ -> acc
          end
      end
    end)
  end

  defp to_string_or_empty(nil), do: ""
  defp to_string_or_empty(value), do: to_string(value)
end
