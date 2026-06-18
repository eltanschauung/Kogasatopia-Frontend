defmodule KogasaFrontend.Tf2ClassesTest do
  use ExUnit.Case, async: true

  alias KogasaFrontend.Tf2Classes

  test "info classes use the intended display order with all-class last" do
    assert Tf2Classes.info_classes() |> Enum.map(& &1.key) ==
             ~w(scout soldier pyro demoman heavy engineer medic sniper spy all_class)
  end

  test "leaderboard icon lookup accepts ids and labels" do
    assert Tf2Classes.leaderboard_icon_for_id("3") ==
             {:ok, {"Soldier", "/leaderboard/Soldier.png"}}

    assert Tf2Classes.leaderboard_icon_for_label("Spy") == {:ok, {"Spy", "/leaderboard/Spy.png"}}
    assert Tf2Classes.leaderboard_icon_for_id("bad") == :error
  end
end
