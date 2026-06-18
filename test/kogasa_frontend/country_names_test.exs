defmodule KogasaFrontend.CountryNamesTest do
  use ExUnit.Case, async: true

  alias KogasaFrontend.CountryNames

  test "normalizes flag codes for filenames" do
    assert CountryNames.normalize_code(" CA ") == "ca"
    assert CountryNames.normalize_code(nil) == ""
  end

  test "metadata uses lowercase codes and a display name" do
    assert %{code: "zz", name: "ZZ"} = CountryNames.metadata("ZZ")
    assert CountryNames.metadata("") == nil
  end
end
