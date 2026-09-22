defmodule KogasaFrontend.WeaponsConfig do
  @moduledoc false

  import KogasaFrontend.Value, only: [truthy?: 1]

  alias KogasaFrontend.ValveKeyValues

  @item_classes_section "ItemClasses"
  @root_section "Weapons"
  @custom_items_section "CustomWeapons"
  @config_filename "weapons.cfg"
  @repo_fallback "/home/kogasa/Kogasatopia/tf/addons/sourcemod/configs/weapons.cfg"
  @default_custom_image "100px-item_icon_wrangler.png"
  @tf2_class_keys ~w(scout soldier pyro demoman heavy engineer medic sniper spy)
  @all_class_key "all_class"
  @custom_inherit_class_rules [
    {~r/TF_WEAPON_SHOTGUN_PYRO|SHOTGUN_PYRO|FIREAXE|FLAMETHROWER|FLAREGUN/i, ["pyro"]},
    {~r/TF_WEAPON_SHOTGUN_HWG|SHOTGUN_HWG|TF_WEAPON_MINIGUN|MINIGUN/i, ["heavy"]},
    {~r/TF_WEAPON_SHOTGUN_SOLDIER|SHOTGUN_SOLDIER|TF_WEAPON_SHOTGUN_PRIMARY|Equalizer|Disciplinary Action|Market Gardener|Buff Banner|Battalion|Concheror|ROCKETLAUNCHER/i,
     ["soldier"]},
    {~r/TF_WEAPON_SCATTERGUN|SCATTERGUN|Baby Face|Crit-a-Cola|Wrap Assassin|PISTOL_SCOUT/i,
     ["scout"]},
    {~r/SNIPERRIFLE|Huntsman|SMG/i, ["sniper"]},
    {~r/PIPEBOMBLAUNCHER|GRENADELAUNCHER|Scottish Resistance|Iron Bomber|Claidheamh/i,
     ["demoman"]},
    {~r/PDA_ENGINEER|Wrench|Sentry|Dispenser/i, ["engineer"]},
    {~r/MEDIGUN|SYRINGEGUN|BONESAW|CROSSBOW|Crusader/i, ["medic"]},
    {~r/REVOLVER|KNIFE|Dead Ringer|Ap-Sap|Enforcer/i, ["spy"]},
    {~r/Prinny Machete/i, @tf2_class_keys}
  ]

  def items_by_class(classes, path \\ config_path()) do
    root = load_weapons_root(path)
    standard_items = standard_items_by_class(classes, root)
    custom_items = custom_items_by_class(classes, root)
    all_class_custom_items = Map.get(custom_items, @all_class_key, [])

    Enum.into(classes, %{}, fn %{key: class_key} ->
      class_custom_items = Map.get(custom_items, class_key, [])

      class_custom_items =
        if class_key == @all_class_key do
          class_custom_items
        else
          class_custom_items ++ all_class_custom_items
        end

      {class_key, Map.get(standard_items, class_key, []) ++ class_custom_items}
    end)
  end

  def custom_item_names(path \\ config_path()) do
    path
    |> load_weapons_root()
    |> custom_items_root()
    |> Enum.reduce(%{}, fn
      {item_key, children}, acc when is_list(children) ->
        Map.put(acc, item_key, value(children, "name", item_key))

      _, acc ->
        acc
    end)
  end

  defp standard_items_by_class(classes, root) do
    class_map = section(root, @item_classes_section) || []
    weapon_sections = weapon_sections(root)

    Enum.into(classes, %{}, fn %{key: class_key} ->
      {class_key, class_items(class_map, class_key, weapon_sections)}
    end)
  end

  defp custom_items_by_class(classes, root) do
    class_keys = Enum.map(classes, & &1.key)
    blank_map = Map.new(class_keys, &{&1, []})

    root
    |> custom_items_root()
    |> Enum.reduce(blank_map, fn
      {item_key, children}, acc when is_list(children) ->
        item = normalize_custom_item(item_key, children)

        children
        |> custom_class_keys(class_keys)
        |> Enum.reduce(acc, fn class_key, class_acc ->
          Map.update!(class_acc, class_key, &[item | &1])
        end)

      _, acc ->
        acc
    end)
    |> Enum.into(%{}, fn {class_key, items} ->
      {class_key, items |> Enum.reverse() |> dedupe_items()}
    end)
  end

  def config_path do
    local_config_path(@config_filename, @repo_fallback)
  end

  defp local_config_path(filename, fallback) do
    cwd_config = Path.expand(filename, File.cwd!())

    cond do
      File.exists?(cwd_config) -> cwd_config
      File.exists?(fallback) -> fallback
      true -> cwd_config
    end
  end

  defp load_weapons_root(path) do
    path
    |> load_entries()
    |> root_entries()
  end

  defp custom_items_root(root) do
    case section(root, @custom_items_section) do
      entries when is_list(entries) -> entries
      _ -> []
    end
  end

  defp load_entries(path) do
    ValveKeyValues.load_file(path)
  end

  defp root_entries(entries), do: section(entries, @root_section) || entries

  defp weapon_sections(root) do
    keyed =
      root
      |> Enum.filter(fn
        {@item_classes_section, _} -> false
        {@custom_items_section, _} -> false
        {_, children} -> is_list(children)
      end)
      |> Map.new()

    tokenized =
      Enum.reduce(keyed, %{}, fn {item_key, children}, acc ->
        item_key
        |> split_item_key()
        |> Enum.reduce(acc, &Map.put_new(&2, &1, children))
      end)

    %{keyed: keyed, tokenized: tokenized}
  end

  defp class_items(class_map, class_key, weapon_sections) do
    class_map
    |> section(class_key)
    |> List.wrap()
    |> Enum.reduce({[], MapSet.new()}, fn {item_key, _}, {items, seen} ->
      case item_for_key(item_key, weapon_sections) do
        nil ->
          {items, seen}

        item ->
          dedupe_key = item_dedupe_key(item)

          if MapSet.member?(seen, dedupe_key) do
            {items, seen}
          else
            {[item | items], MapSet.put(seen, dedupe_key)}
          end
      end
    end)
    |> elem(0)
    |> Enum.reverse()
  end

  defp item_for_key(item_key, %{keyed: keyed, tokenized: tokenized}) do
    with children when is_list(children) <-
           Map.get(keyed, item_key) || Map.get(tokenized, item_key),
         item <- normalize_item(item_key, children),
         false <- blank_effects?(item) do
      item
    else
      _ -> nil
    end
  end

  defp normalize_item(item_key, children) do
    description = section(children, "description") || []

    %{
      key: item_key,
      name: value(children, "name", item_key),
      image: value(children, "image", ""),
      type: value(description, "type", ""),
      weapon_type: value(children, "type", ""),
      points_store_purchase: value(children, "points_store_purchase", ""),
      hidden: hidden_item?(children),
      reskin_only: truthy_value?(value(children, "reskin_only", "")),
      all_class: false,
      positive: value(description, "positive", ""),
      neutral: value(description, "neutral", ""),
      negative: value(description, "negative", "")
    }
  end

  defp normalize_custom_item(item_key, children) do
    description = custom_description(children)

    %{
      key: item_key,
      name: value(children, "name", item_key),
      image: first_value(children, ["image", "icon"], @default_custom_image),
      type: "custom",
      weapon_type: value(children, "type", ""),
      points_store_purchase: value(children, "points_store_purchase", ""),
      hidden: hidden_item?(children),
      reskin_only: truthy_value?(value(children, "reskin_only", "")),
      all_class: truthy_value?(value(children, "all_class", "")),
      positive: value(description, "positive", ""),
      neutral: value(description, "neutral", ""),
      negative: value(description, "negative", "")
    }
  end

  defp custom_description(children) do
    Enum.find_value(children, [], fn
      {"description", description} when is_list(description) ->
        description

      {"description", description} when is_binary(description) ->
        [{"positive", String.trim(description)}, {"neutral", ""}, {"negative", ""}]

      _ ->
        nil
    end)
  end

  defp custom_class_keys(children, allowed_class_keys) do
    if truthy_value?(value(children, "all_class", "")) and @all_class_key in allowed_class_keys do
      [@all_class_key]
    else
      custom_regular_class_keys(children, allowed_class_keys)
    end
  end

  defp custom_regular_class_keys(children, allowed_class_keys) do
    explicit =
      children
      |> section("used_by_classes")
      |> List.wrap()
      |> Enum.filter(fn
        {class_key, slot} when is_binary(slot) ->
          class_key in allowed_class_keys and String.trim(slot) != ""

        _ ->
          false
      end)
      |> Enum.map(&elem(&1, 0))

    case explicit do
      [] -> fallback_custom_class_keys(children, allowed_class_keys)
      _ -> explicit
    end
  end

  defp fallback_custom_class_keys(children, allowed_class_keys) do
    haystack =
      [value(children, "inherits", ""), value(children, "item_class", "")]
      |> Enum.join(" ")

    @custom_inherit_class_rules
    |> Enum.find_value([], fn {pattern, classes} ->
      if Regex.match?(pattern, haystack) do
        Enum.filter(classes, &(&1 in allowed_class_keys))
      end
    end)
  end

  defp truthy_value?(value), do: truthy?(value)

  defp hidden_item?(children), do: truthy_value?(value(children, "hidden", ""))

  defp blank_effects?(%{positive: positive, neutral: neutral, negative: negative}) do
    [positive, neutral, negative]
    |> Enum.map(&String.trim/1)
    |> Enum.all?(&(&1 == ""))
  end

  defp item_dedupe_key(%{
         name: name,
         positive: positive,
         neutral: neutral,
         negative: negative,
         image: image,
         reskin_only: reskin_only
       }) do
    Enum.join([name, positive, neutral, negative, image, reskin_only], "|")
  end

  defp dedupe_items(items) do
    items
    |> Enum.reduce({[], MapSet.new()}, fn item, {kept, seen} ->
      dedupe_key = item_dedupe_key(item)

      if MapSet.member?(seen, dedupe_key) do
        {kept, seen}
      else
        {[item | kept], MapSet.put(seen, dedupe_key)}
      end
    end)
    |> elem(0)
    |> Enum.reverse()
  end

  defp section(entries, key), do: ValveKeyValues.section(entries, key)

  defp first_value(entries, keys, default) do
    Enum.find_value(keys, default, fn key ->
      case value(entries, key, "") do
        "" -> nil
        value -> value
      end
    end)
  end

  defp value(entries, key, default) do
    ValveKeyValues.value(entries, key, default)
  end

  defp split_item_key(item_key) do
    item_key
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end
end
