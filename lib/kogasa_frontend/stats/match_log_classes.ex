defmodule KogasaFrontend.Stats.MatchLogClasses do
  @moduledoc false

  import KogasaFrontend.Value, only: [float: 1, int: 1, str: 1]

  @healing_per_shot_equivalent 10.0
  @spy_backstab_shot_equivalent 5
  @class_threshold 0.33
  @max_class_icons 3

  def build(row, weapon_summary) do
    weapon_summary
    |> Enum.reduce(%{}, &put_candidate/2)
    |> maybe_add_spy_backstabs(row)
    |> Map.values()
    |> maybe_add_medic(row)
    |> Enum.sort_by(fn item -> {-float(item["score"]), -float(item["accuracy"])} end)
    |> apply_threshold()
  end

  defp put_candidate(item, candidates) do
    class_slug = class_slug_for_weapon(str(item["slug"]))
    shots = float(item["shots"])

    if class_slug == "" or shots <= 0.0 do
      candidates
    else
      hits = int(item["hits"])

      Map.update(
        candidates,
        class_slug,
        candidate(class_slug, shots, hits),
        &merge_candidate(&1, shots, hits)
      )
    end
  end

  defp merge_candidate(existing, extra_score, extra_hits) do
    score = float(existing["score"]) + extra_score
    hits = int(existing["hits"]) + extra_hits

    existing
    |> Map.put("score", score)
    |> Map.put("shots", score)
    |> Map.put("title_value", score)
    |> Map.put("hits", hits)
    |> Map.put("accuracy", if(score > 0.0, do: hits / score * 100.0, else: 0.0))
  end

  defp maybe_add_spy_backstabs(candidates, row) do
    backstab_score = int(row["backstabs"]) * @spy_backstab_shot_equivalent

    if backstab_score <= 0 do
      candidates
    else
      Map.update(
        candidates,
        "spy",
        candidate("spy", backstab_score, 0),
        &merge_candidate(&1, backstab_score, 0)
      )
    end
  end

  defp maybe_add_medic(candidates, row) do
    medic_shots = int(row["shots_medic"])
    healing = int(row["healing"])
    medic_score = medic_shots + healing / @healing_per_shot_equivalent

    if medic_score <= 0.0 do
      candidates
    else
      [
        "medic"
        |> candidate(medic_score, 0)
        |> Map.put("title_value", healing)
        |> Map.put("title_metric", "healing")
        | candidates
      ]
    end
  end

  defp apply_threshold([]), do: []

  defp apply_threshold([top | _] = candidates) do
    top_score = float(top["score"])

    if top_score <= 0.0 do
      []
    else
      minimum_score = top_score * @class_threshold

      candidates
      |> Enum.filter(&(float(&1["score"]) >= minimum_score))
      |> Enum.take(@max_class_icons)
    end
  end

  defp candidate(slug, score, hits) do
    %{
      "slug" => slug,
      "label" => class_label(slug),
      "score" => score,
      "shots" => score,
      "title_value" => score,
      "title_metric" => "shots",
      "hits" => hits,
      "accuracy" => if(score > 0.0, do: hits / score * 100.0, else: 0.0)
    }
  end

  defp class_slug_for_weapon("scatterguns"), do: "scout"
  defp class_slug_for_weapon("snipers"), do: "sniper"
  defp class_slug_for_weapon("rocketlaunchers"), do: "soldier"
  defp class_slug_for_weapon("grenadelaunchers"), do: "demoman"
  defp class_slug_for_weapon("stickylaunchers"), do: "demoman"
  defp class_slug_for_weapon("revolvers"), do: "spy"
  defp class_slug_for_weapon("shotguns"), do: "engineer"
  defp class_slug_for_weapon("pistols"), do: "engineer"
  defp class_slug_for_weapon(_), do: ""

  defp class_label("scout"), do: "Scout"
  defp class_label("sniper"), do: "Sniper"
  defp class_label("soldier"), do: "Soldier"
  defp class_label("demoman"), do: "Demoman"
  defp class_label("medic"), do: "Medic"
  defp class_label("heavy"), do: "Heavy"
  defp class_label("pyro"), do: "Pyro"
  defp class_label("spy"), do: "Spy"
  defp class_label("engineer"), do: "Engineer"
  defp class_label(_), do: "Class"
end
