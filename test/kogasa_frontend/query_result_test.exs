defmodule KogasaFrontend.QueryResultTest do
  use ExUnit.Case, async: true

  alias KogasaFrontend.QueryResult

  test "maps query rows with string keys by default" do
    assert QueryResult.rows_to_maps([[1, "Scout"], [2, "Soldier"]], ["id", "name"]) == [
             %{"id" => 1, "name" => "Scout"},
             %{"id" => 2, "name" => "Soldier"}
           ]
  end

  test "maps query rows with atom keys when requested" do
    assert QueryResult.rows_to_maps([[24, 60]], ["players", "duration"], :atoms) == [
             %{players: 24, duration: 60}
           ]
  end

  test "maps one row against preformatted columns" do
    assert QueryResult.row_to_map(["7656119", 12], ["steamid", "kills"]) == %{
             "steamid" => "7656119",
             "kills" => 12
           }
  end
end
