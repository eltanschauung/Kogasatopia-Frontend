defmodule KogasaFrontend.MapsDb.SectionsTest do
  use ExUnit.Case, async: true

  alias KogasaFrontend.MapsDb.Sections

  test "orders API rows by gamemodes first, then known categories, then leftovers" do
    rows = [
      %{"name" => "custom_weird", "modified" => 1, "size" => 1},
      %{"name" => "cp_badlands", "modified" => 1, "size" => 1},
      %{"name" => "payload", "modified" => 1, "size" => 1},
      %{"name" => "koth_harvest_final", "modified" => 1, "size" => 1},
      %{"name" => "arena", "modified" => 1, "size" => 1}
    ]

    categories = %{
      "cp_badlands" => "cp",
      "koth_harvest_final" => "koth",
      "custom_weird" => "zzcustom"
    }

    ordered = Sections.order_api_rows(rows, categories)

    assert Enum.map(ordered, & &1["name"]) == [
             "arena",
             "payload",
             "koth_harvest_final",
             "cp_badlands",
             "custom_weird"
           ]

    assert Enum.map(ordered, & &1["type"]) == ["gamemode", "gamemode", "map", "map", "map"]
    refute Enum.any?(ordered, &Map.has_key?(&1, "order"))
  end

  test "builds page sections with harvest subcategories before category buckets" do
    map_names = ["cp_badlands", "koth", "koth_harvest_final", "mystery_map"]

    meta = %{
      "cp_badlands" => %{category: "cp", sub_category: ""},
      "koth_harvest_final" => %{category: "koth", sub_category: "harvest"}
    }

    sections = Sections.build_map_sections(map_names, meta)

    assert Enum.map(sections, & &1.slug) == ["subcat-harvest", "gamemode", "cp", "_other"]

    assert Enum.map(sections, & &1.label) == [
             "Harvest-type maps",
             "Gamemode configs",
             "Control Point maps",
             "Other maps"
           ]

    assert [harvest_entry] = hd(sections).entries
    assert harvest_entry.name == "koth_harvest_final"
    assert harvest_entry.source == "mapsdb"
  end
end
