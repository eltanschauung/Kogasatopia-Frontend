defmodule KogasaFrontend.MapsDb.Source do
  @moduledoc false

  def sanitize(source), do: {:ok, normalize(source)}

  def normalize("tfcfg"), do: "tfcfg"
  def normalize(_source), do: "mapsdb"
end
