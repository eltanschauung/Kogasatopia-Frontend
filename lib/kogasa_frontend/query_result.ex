defmodule KogasaFrontend.QueryResult do
  @moduledoc false

  def rows_to_maps(rows, columns, key_format \\ :strings) do
    keys = Enum.map(columns, &format_key(&1, key_format))
    Enum.map(rows, &row_to_map(&1, keys))
  end

  def row_to_map(row, columns), do: Enum.zip(columns, row) |> Map.new()

  defp format_key(key, :strings) when is_binary(key), do: key
  defp format_key(key, :strings), do: to_string(key)
  defp format_key(key, :atoms) when is_atom(key), do: key
  defp format_key(key, :atoms) when is_binary(key), do: String.to_atom(key)
end
