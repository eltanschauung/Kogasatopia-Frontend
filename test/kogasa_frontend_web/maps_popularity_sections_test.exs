defmodule KogasaFrontendWeb.MapsPopularitySectionsTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest

  test "renders the shop table using the existing layout and escapes item names" do
    row = %{
      map_name: "fixture",
      sessions: 1,
      avg_players_display: "1",
      peak_players: 1,
      player_hours_display: "1",
      first15_avg_display: "1",
      first15_growth_display: "0",
      best_slot: "fixture",
      best_slot_avg_display: "1",
      joins: 1,
      leaves: 0,
      rtvs: 0,
      nominations: 0
    }

    data = %{
      popularity_active_hours: 0,
      popularity_chart: %{"labels" => []},
      maps_dir_missing: true,
      maps_dir: "/fixture/maps",
      map_analytics: %{
        rows: [row],
        vote_table_available: true,
        popular_custom_weapons: [%{name: "Fixture Weapon", equipped_clients: 2}],
        popular_custom_hats: [%{name: "Fixture Hat", equipped_clients: 3}],
        common_shop_purchases: [%{name: "Pack <safe>", purchasers: 4}]
      }
    }

    html =
      render_component(&KogasaFrontendWeb.MapsDbHTML.index/1,
        mapsdb: data,
        maps_cache_hash: nil,
        maps_cache_generated_at: "",
        popular_maps: [],
        map_sections: [],
        map_previews: [],
        chart_json: "{}"
      )

    assert html =~ "Pack &lt;safe&gt;"
    assert html =~ "Players with a recorded paid purchase"
    {weapon_at, _} = :binary.match(html, "Most Popular Custom Weapons")
    {hat_at, _} = :binary.match(html, "Most Popular Custom Hats")
    {shop_at, _} = :binary.match(html, "Most Common Shop Purchases")
    assert weapon_at < hat_at and hat_at < shop_at
  end

  test "popular item sections are adjacent and ordered weapons, hats, shop" do
    template =
      File.read!(
        Path.expand(
          "../../lib/kogasa_frontend_web/controllers/maps_db_html/index.html.heex",
          __DIR__
        )
      )

    titles =
      Regex.scan(~r/<h3 class="map-analytics-title">([^<]+)<\/h3>/, template,
        capture: :all_but_first
      )
      |> List.flatten()

    wanted = [
      "Most Popular Custom Weapons",
      "Most Popular Custom Hats",
      "Most Common Shop Purchases"
    ]

    first = Enum.find_index(titles, &(&1 == hd(wanted)))
    assert Enum.slice(titles, first, 3) == wanted
    for title <- wanted, do: assert(Enum.count(titles, &(&1 == title)) == 1)
    assert template =~ "analytics[:common_shop_purchases]"
    assert template =~ "{item.name}"
    assert template =~ "{item.purchasers}"
    refute template =~ "raw(item.name)"
  end
end
