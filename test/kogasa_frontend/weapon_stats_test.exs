defmodule KogasaFrontend.WeaponStatsTest do
  use ExUnit.Case, async: true

  alias KogasaFrontend.WeaponStats

  test "builds and orders category summaries by shot count" do
    row = %{
      "shots_rocketlaunchers" => 20,
      "hits_rocketlaunchers" => 10,
      "shots_shotguns" => 5,
      "hits_shotguns" => 4
    }

    assert [rockets, shotgun] = WeaponStats.summary(row)
    assert rockets["slug"] == "rocketlaunchers"
    assert rockets["accuracy"] == 50.0
    assert shotgun["slug"] == "shotguns"
    assert shotgun["accuracy"] == 80.0
  end

  test "falls back to overall accuracy when category data is absent" do
    assert [%{"slug" => "overall", "shots" => 12, "hits" => 3, "accuracy" => 25.0}] =
             WeaponStats.summary(%{"shots" => 12, "hits" => 3})
  end

  test "ignores incomplete weapon slot records" do
    row = %{
      "weapon1_name" => "Rocket Launcher",
      "weapon1_accuracy" => 40.0,
      "weapon1_shots" => 10,
      "weapon1_hits" => 4,
      "weapon2_name" => "",
      "weapon2_accuracy" => 100.0,
      "weapon2_shots" => 1,
      "weapon2_hits" => 1
    }

    assert [
             %{
               "name" => "Rocket Launcher",
               "accuracy" => 40.0,
               "shots" => 10,
               "hits" => 4
             }
           ] = WeaponStats.slot_accuracy_summary(row, 2)
  end
end
