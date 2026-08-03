defmodule KogasaFrontend.QuickstatsTest do
  use ExUnit.Case, async: true

  alias KogasaFrontend.Quickstats

  test "parses server and player fields" do
    assert %{
             server_name: "kogasa.tf | New Jersey | Custom Weapons",
             port: "27015",
             player_count: "2 / 24",
             map_name: "pl_badwater",
             players: ["Alice[X]Soldier", "Bob[X]Medic"]
           } =
             Quickstats.parse_lines([
               "Hostname: kogasa.tf | New Jersey | Custom Weapons",
               "Port: 27015",
               "Player Count: 2 / 24",
               "Map Name: pl_badwater.bsp",
               "Player 1: Alice[X]Soldier",
               "Player 2: Bob[X]Medic"
             ])
  end

  test "normalizes the public hostname and known server ports" do
    assert Quickstats.compact_hostname("kogasa.tf | New Jersey | Custom Weapons") ==
             "kogasa.tf | New Jersey"

    assert Quickstats.compact_hostname("", "fallback") == "fallback"
    assert Quickstats.file_for_port("27016") == "server27016_quickstats.txt"
    assert Quickstats.file_for_port(1) == nil
  end
end
