defmodule KogasaFrontend.WeaponStats do
  @moduledoc false

  import KogasaFrontend.Value, only: [float: 1, int: 1, str: 1]

  alias KogasaFrontend.WeaponCategories

  @category_metadata WeaponCategories.metadata()
  @category_slugs WeaponCategories.slugs()

  def summary_with_active(row) when is_map(row) do
    summary = summary(row)
    {summary, List.first(summary)}
  end

  def summary(row) when is_map(row) do
    @category_metadata
    |> Enum.reduce([], fn {slug, meta}, acc ->
      shots = int(row["shots_#{slug}"])
      hits = int(row["hits_#{slug}"])

      if shots <= 0 do
        acc
      else
        [
          %{
            "slug" => slug,
            "label" => meta.label,
            "shots" => shots,
            "hits" => hits,
            "accuracy" => hits / max(shots, 1) * 100.0
          }
          | acc
        ]
      end
    end)
    |> Enum.sort_by(fn item -> {-int(item["shots"]), -float(item["accuracy"])} end)
    |> fallback_overall(row)
  end

  def slot_accuracy_summary(row, max_slots \\ 3) when is_map(row) do
    slots = if max_slots > 0, do: 1..max_slots, else: []

    Enum.reduce(slots, [], fn slot, acc ->
      name = row["weapon#{slot}_name"] |> str() |> String.trim()
      accuracy = row["weapon#{slot}_accuracy"]
      shots = int(row["weapon#{slot}_shots"])
      hits = int(row["weapon#{slot}_hits"])

      if name == "" or is_nil(accuracy) or shots <= 0 do
        acc
      else
        acc ++
          [%{"name" => name, "accuracy" => float(accuracy), "shots" => shots, "hits" => hits}]
      end
    end)
  end

  def total_accuracy_counts(row) when is_map(row) do
    {total_shots, total_hits} =
      Enum.reduce(@category_slugs, {0, 0}, fn slug, {shots_acc, hits_acc} ->
        {
          shots_acc + int(row["shots_#{slug}"]),
          hits_acc + int(row["hits_#{slug}"])
        }
      end)

    if total_shots == 0 and Map.has_key?(row, "shots") and Map.has_key?(row, "hits") do
      {int(row["shots"]), int(row["hits"])}
    else
      {total_shots, total_hits}
    end
  end

  defp fallback_overall([], row) do
    {shots, hits} = total_accuracy_counts(row)

    if shots > 0 do
      [
        %{
          "slug" => "overall",
          "label" => "Overall",
          "shots" => shots,
          "hits" => hits,
          "accuracy" => hits / max(shots, 1) * 100.0
        }
      ]
    else
      []
    end
  end

  defp fallback_overall(summary, _row), do: summary
end
