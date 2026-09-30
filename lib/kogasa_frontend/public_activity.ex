defmodule KogasaFrontend.PublicActivity do
  @moduledoc false

  @default_path "/home/kogasa/hlserver/tf2/tf/addons/sourcemod/configs/public_activity_exclusions.txt"

  def excluded_ids do
    path = Application.get_env(:kogasa_frontend, :public_activity_exclusions_file, @default_path)

    case File.read(path) do
      {:ok, contents} -> parse(contents)
      {:error, _} -> []
    end
  end

  def parse(contents) do
    contents
    |> String.split(~r/\r?\n/)
    |> Enum.map(&String.trim/1)
    |> Enum.filter(&Regex.match?(~r/\A[0-9]{17}\z/, &1))
    |> Enum.uniq()
  end

  def excluded?(steamid), do: is_binary(steamid) and steamid in excluded_ids()

  # These are bound SQL parameters, never interpolated account values.
  def sql_filter(column, ids) when column in ["steamid", "o.steamid"] do
    if ids == [] do
      {"1 = 1", []}
    else
      placeholders = Enum.map_join(ids, ",", fn _ -> "?" end)
      {"(#{column} IS NULL OR #{column} NOT IN (#{placeholders}))", ids}
    end
  end
end
