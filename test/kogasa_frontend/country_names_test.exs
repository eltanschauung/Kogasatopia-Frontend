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

  test "uses display names for custom flags" do
    assert CountryNames.display_name("ancap") == "Anarcho-Capitalist"
    assert CountryNames.display_name("DIXIE") == "Dixie"
    assert CountryNames.display_name("millennium") == "Millennium Science School"
  end
end
