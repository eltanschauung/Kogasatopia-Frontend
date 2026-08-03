defmodule KogasaFrontend.MapsDb.SourceTest do
  use ExUnit.Case, async: true

  alias KogasaFrontend.MapsDb.Source

  test "normalizes missing sources to mapsdb" do
    assert Source.sanitize(nil) == {:ok, "mapsdb"}
    assert Source.sanitize("") == {:ok, "mapsdb"}
    assert Source.sanitize("mapsdb") == {:ok, "mapsdb"}
  end

  test "rejects unknown sources" do
    assert Source.sanitize("unexpected") == {:error, :invalid_source}
  end

  test "keeps tfcfg as an editable source" do
    assert Source.sanitize("tfcfg") == {:ok, "tfcfg"}
  end
end
