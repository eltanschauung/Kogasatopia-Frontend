defmodule KogasaFrontend.Stats.MatchLogClassesTest do
  use ExUnit.Case, async: true

  alias KogasaFrontend.Stats.MatchLogClasses

  test "keeps classes at one third of the leading score and limits the result" do
    summary = [
      weapon("rocketlaunchers", 100, 50),
      weapon("scatterguns", 33, 20),
      weapon("snipers", 32, 20),
      weapon("shotguns", 40, 20)
    ]

    assert Enum.map(MatchLogClasses.build(%{}, summary), & &1["slug"]) ==
             ["soldier", "engineer", "scout"]
  end

  test "counts backstabs as five spy shots" do
    assert [%{"slug" => "spy", "score" => 10}] =
             MatchLogClasses.build(%{"backstabs" => 2}, [])
  end

  test "combines medic shots with one shot-equivalent per ten healing" do
    assert [
             %{
               "slug" => "medic",
               "score" => 25.0,
               "title_metric" => "healing",
               "title_value" => 200
             }
           ] =
             MatchLogClasses.build(%{"shots_medic" => 5, "healing" => 200}, [])
  end

  test "combines weapon categories belonging to the same class" do
    [demoman] =
      MatchLogClasses.build(
        %{},
        [weapon("grenadelaunchers", 10, 4), weapon("stickylaunchers", 20, 6)]
      )

    assert demoman["slug"] == "demoman"
    assert demoman["score"] == 30.0
    assert demoman["hits"] == 10
  end

  defp weapon(slug, shots, hits), do: %{"slug" => slug, "shots" => shots, "hits" => hits}
end
