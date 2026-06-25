defmodule KogasaFrontend.MapsDb.Source do
  @moduledoc false

  def sanitize(source) do
    case normalize(source) do
      source when source in ["mapsdb", "tfcfg"] -> {:ok, source}
      _ -> {:error, :invalid_source}
    end
  end

  def normalize("tfcfg"), do: "tfcfg"
  def normalize(nil), do: "mapsdb"
  def normalize(""), do: "mapsdb"
  def normalize("mapsdb"), do: "mapsdb"
  def normalize(_source), do: :invalid
end
