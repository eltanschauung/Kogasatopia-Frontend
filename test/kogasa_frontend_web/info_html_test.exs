defmodule KogasaFrontendWeb.InfoHTMLTest do
  use ExUnit.Case, async: true

  alias KogasaFrontendWeb.InfoHTML

  test "locked shop weapons are muted and cannot be selected" do
    html = render_weapon_tile(true)

    assert html =~ "is-locked"
    assert html =~ "!shop Item"
    refute html =~ "Level 1 Rifle"
    refute html =~ "href="
  end

  test "owned weapons retain their normal type and link" do
    html = render_weapon_tile(false)

    refute html =~ "is-locked"
    refute html =~ "!shop Item"
    assert html =~ "Level 1 Rifle"
    assert html =~ ~s(href="#")
  end

  defp render_weapon_tile(locked) do
    item = %{
      equipped: false,
      locked: locked,
      title: "Test weapon",
      uid: "test_weapon",
      name: "Test Weapon",
      icon: "/test.png",
      type_level: "Level 1 Rifle",
      effects: []
    }

    %{item: item, inert: false, interactive: true}
    |> InfoHTML.weapon_tile()
    |> Phoenix.HTML.Safe.to_iodata()
    |> IO.iodata_to_binary()
  end
end
