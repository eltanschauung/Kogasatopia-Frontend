defmodule KogasaFrontend.MapsDb.SourceTest do
  use ExUnit.Case, async: true

  alias KogasaFrontend.MapsDb.Source

  test "normalizes missing or unknown sources to mapsdb" do
    assert Source.sanitize(nil) == {:ok, "mapsdb"}
    assert Source.sanitize("mapsdb") == {:ok, "mapsdb"}
    assert Source.sanitize("unexpected") == {:ok, "mapsdb"}
  end

  test "keeps tfcfg as an editable source" do
    assert Source.sanitize("tfcfg") == {:ok, "tfcfg"}
  end
end
