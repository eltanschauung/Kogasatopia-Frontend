defmodule KogasaFrontend.MapsDb.Sections do
  @moduledoc false

  @gamemode_names ~w(arena koth payload payloadrace ctf 5cp adcp tc medieval pd tr dm ultiduo rd pass mvm kotf dom default)
  @page_gamemode_names ~w(arena koth payload payloadrace ctf 5cp adcp tc medieval pd tr dm ultiduo rd pass mvm kotf dom symmetrical asymmetrical default)
  @api_category_order ~w(koth cp pl plr ctf pd sd arena zi vsh mge tc tr dm ultiduo rd pass mvm kotf dom)
  @page_category_order ~w(gamemode koth cp pl plr ctf pd sd arena zi vsh mge tc tr dm ultiduo rd pass mvm kotf dom)
  @category_label_map %{
    "koth" => "KOTH maps",
    "cp" => "Control Point maps",
    "pl" => "Payload maps",
    "plr" => "Payload Race maps",
    "ctf" => "Capture the Flag maps",
    "pd" => "Player Destruction maps",
    "sd" => "SD maps",
    "arena" => "Arena maps",
    "zi" => "Zombie Infection maps",
    "vsh" => "Vs. Saxton Hale maps",
    "mge" => "MGE maps",
    "tc" => "Terrain Control maps",
    "tr" => "Training maps",
    "dm" => "Deathmatch maps",
    "ultiduo" => "Ultiduo maps",
    "rd" => "Robot Destruction maps",
    "pass" => "Pass Time maps",
    "mvm" => "Mann vs. Machine maps",
    "kotf" => "King of the Flag maps",
    "dom" => "Domination maps",
    "gamemode" => "Gamemode configs"
  }
  @sub_category_order ["harvest"]
  @sub_category_label_map %{"harvest" => "Harvest-type maps"}

  def order_api_rows(rows, categories) do
    gamemode_order = Enum.with_index(Enum.map(@gamemode_names, &String.downcase/1)) |> Map.new()
    gamemode_set = Map.keys(gamemode_order) |> MapSet.new()

    enriched =
      Enum.map(rows, fn row ->
        name = row["name"]
        lower = String.downcase(name)
        type = if MapSet.member?(gamemode_set, lower), do: "gamemode", else: "map"

        row
        |> Map.put("category", Map.get(categories, name, ""))
        |> Map.put("type", type)
        |> Map.put("order", if(type == "gamemode", do: Map.get(gamemode_order, lower), else: nil))
      end)

    {gamemodes, maps} = Enum.split_with(enriched, &(&1["type"] == "gamemode"))

    gamemodes_sorted =
      Enum.sort_by(gamemodes, fn row ->
        {row["order"] || 99_999, String.downcase(row["name"])}
      end)

    grouped =
      Enum.group_by(maps, fn row ->
        cat = row["category"]
        if cat == "", do: "_other", else: String.downcase(cat)
      end)

    ordered_maps =
      @api_category_order
      |> Enum.reduce({[], grouped}, fn cat_key, {acc, buckets} ->
        case Map.pop(buckets, cat_key) do
          {nil, rest} -> {acc, rest}
          {bucket, rest} -> {acc ++ Enum.sort_by(bucket, &String.downcase(&1["name"])), rest}
        end
      end)
      |> then(fn {acc, buckets} ->
        tail =
          buckets
          |> Enum.sort_by(fn {k, _} -> k end)
          |> Enum.flat_map(fn {_k, bucket} ->
            Enum.sort_by(bucket, &String.downcase(&1["name"]))
          end)

        acc ++ tail
      end)

    (gamemodes_sorted ++ ordered_maps)
    |> Enum.map(&Map.delete(&1, "order"))
  end

  def build_map_sections(map_names, map_meta) do
    gamemode_set = @page_gamemode_names |> Enum.map(&String.downcase/1) |> MapSet.new()

    {sub_buckets, cat_buckets} =
      Enum.reduce(map_names, {%{}, %{}}, fn map_name, {sub_acc, cat_acc} ->
        lower = String.downcase(map_name)
        meta = Map.get(map_meta, map_name, %{category: "", sub_category: ""})
        category = meta.category || ""
        sub_category = meta.sub_category || ""

        entry = %{
          name: map_name,
          display: map_name,
          type: if(MapSet.member?(gamemode_set, lower), do: "gamemode", else: "map"),
          category: category,
          sub_category: sub_category,
          source: "mapsdb"
        }

        sub_key = String.downcase(sub_category)

        cond do
          sub_key != "" and Map.has_key?(@sub_category_label_map, sub_key) ->
            {Map.update(sub_acc, sub_key, [entry], &[entry | &1]), cat_acc}

          true ->
            bucket_key =
              cond do
                entry.type == "gamemode" and category == "" -> "gamemode"
                category == "" -> "_other"
                true -> String.downcase(category)
              end

            {sub_acc, Map.update(cat_acc, bucket_key, [entry], &[entry | &1])}
        end
      end)

    sub_sections =
      Enum.reduce(@sub_category_order, {[], sub_buckets}, fn sub_key, {acc, buckets} ->
        case Map.pop(buckets, sub_key) do
          {nil, rest} ->
            {acc, rest}

          {entries, rest} ->
            sorted = Enum.sort_by(entries, &String.downcase(&1.name))

            section = %{
              label: @sub_category_label_map[sub_key],
              slug: "subcat-" <> sub_key,
              entries: sorted,
              open: false
            }

            {acc ++ [section], rest}
        end
      end)
      |> then(fn {acc, _rest} -> acc end)

    ordered_cat_sections =
      Enum.reduce(@page_category_order, {[], cat_buckets}, fn cat_key, {acc, buckets} ->
        case Map.pop(buckets, cat_key) do
          {nil, rest} ->
            {acc, rest}

          {entries, rest} ->
            sorted = Enum.sort_by(entries, &String.downcase(&1.name))

            section = %{
              label: format_category_label(cat_key),
              slug: cat_key,
              entries: sorted,
              open: false
            }

            {acc ++ [section], rest}
        end
      end)
      |> then(fn {acc, rest} ->
        extra =
          rest
          |> Enum.sort_by(fn {k, _} -> k end)
          |> Enum.map(fn {bucket_key, entries} ->
            %{
              label: format_category_label(bucket_key),
              slug: bucket_key,
              entries: Enum.sort_by(entries, &String.downcase(&1.name)),
              open: false
            }
          end)

        acc ++ extra
      end)

    sub_sections ++ ordered_cat_sections
  end

  def format_category_label(slug) do
    key = String.downcase(to_string(slug || ""))

    cond do
      Map.has_key?(@category_label_map, key) -> @category_label_map[key]
      key in ["", "_other"] -> "Other maps"
      true -> String.upcase(key) <> " maps"
    end
  end
end
