defmodule KogasaFrontend.InfoPageTest do
  use ExUnit.Case, async: true

  alias KogasaFrontend.InfoPage

  test "normal and custom in-game views share custom weapon ordering" do
    normal = InfoPage.assigns()
    custom_ingame = InfoPage.assigns("scout-custom-ingame")

    normal_custom_uids =
      normal.initial_items
      |> Enum.filter(& &1.is_custom)
      |> Enum.map(& &1.uid)

    assert normal_custom_uids == Enum.map(custom_ingame.initial_items, & &1.uid)

    assert Enum.map(normal.initial_items, & &1.display_order) ==
             normal.initial_items
             |> Enum.map(& &1.display_order)
             |> Enum.sort()
  end
end
