defmodule KogasaFrontendWeb.InfoHTMLTest do
  use ExUnit.Case, async: true

  alias KogasaFrontendWeb.InfoHTML
  alias KogasaFrontend.InfoPage

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
    assert html =~ ~s(width="96" height="96")
    refute html =~ "style=\"color:"
  end

  test "hat label colors override gold only when a valid chat color is configured" do
    assert render_weapon_tile(false, %{kind: :solid, color: "#FF4040"}) =~
             ~s(style="color: #FF4040")

    gradient = %{
      kind: :gradient,
      first: "#FF4040",
      second: "#00FF7F",
      completion: 50
    }

    gradient_html = render_weapon_tile(false, gradient)
    assert gradient_html =~ "chat-name-gradient"
    assert gradient_html =~ "linear-gradient(90deg, #FF4040 0%, #00FF7F 50%, #00FF7F 100%)"
    refute render_weapon_tile(false) =~ "style=\"color:"
  end

  test "hats use one grid in slot order without separators while weapons retain theirs" do
    hats = InfoPage.assigns("hats-ingame")
    hats_html = hats |> InfoHTML.index() |> Phoenix.HTML.Safe.to_iodata() |> IO.iodata_to_binary()

    assert length(Regex.scan(~r/class="weapons-ingame-grid"/, hats_html)) == 1

    assert length(Regex.scan(~r/width="150" height="150"/, hats_html)) ==
             length(hats.initial_items)

    assert hats_html =~ "weapons-hats-ingame"
    refute hats_html =~ "tab-button-label--desktop"
    refute hats_html =~ "<hr"

    rendered_uids =
      ~r/data-weapon-uid="([^"]+)"/
      |> Regex.scan(hats_html, capture: :all_but_first)
      |> List.flatten()

    expected_uids =
      hats.initial_hat_groups
      |> Enum.flat_map(fn group -> group.items end)
      |> Enum.map(& &1.uid)

    assert rendered_uids == expected_uids

    weapons_html =
      "scout-custom-ingame"
      |> InfoPage.assigns()
      |> InfoHTML.index()
      |> Phoenix.HTML.Safe.to_iodata()
      |> IO.iodata_to_binary()

    assert weapons_html =~ "Custom Weapons"
    assert weapons_html =~ "Reskins"
    assert length(Regex.scan(~r/class="weapons-ingame-group"/, weapons_html)) == 2
    refute weapons_html =~ "weapons-hats-ingame"
    refute weapons_html =~ "chat-name-gradient"
    assert weapons_html =~ ~s(width="96" height="96")
  end

  defp render_weapon_tile(locked, label_style \\ nil) do
    item = %{
      equipped: false,
      locked: locked,
      title: "Test weapon",
      uid: "test_weapon",
      name: "Test Weapon",
      icon: "/test.png",
      type_level: "Level 1 Rifle",
      effects: [],
      label_style: label_style
    }

    %{item: item, inert: false, interactive: true}
    |> InfoHTML.weapon_tile()
    |> Phoenix.HTML.Safe.to_iodata()
    |> IO.iodata_to_binary()
  end
end
