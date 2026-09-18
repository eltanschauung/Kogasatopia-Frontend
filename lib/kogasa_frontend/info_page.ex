defmodule KogasaFrontend.InfoPage do
  @moduledoc false

  alias KogasaFrontend.Tf2Classes
  alias KogasaFrontend.WeaponPanel
  alias KogasaFrontend.WeaponsConfig

  @active_class "scout"
  @classes Tf2Classes.info_classes()
  @class_icons Map.new(@classes, fn %{key: key, icon: icon} -> {key, icon} end)
  @class_aliases %{"demo" => "demoman", "engi" => "engineer", "all" => "all_class"}

  def assigns(view \\ nil, session_token \\ nil) do
    items_by_class = load_items_by_class()
    initial_state = initial_state(view, items_by_class)
    panel_session = panel_session(session_token, initial_state)

    initial_items =
      items_by_class
      |> initial_items(initial_state)
      |> mark_equipped(panel_session)

    config_update = config_update_metadata()

    %{
      classes: @classes,
      active_class: initial_state.active_class,
      initial_items: initial_items,
      initial_custom_items: section_items(initial_items, false),
      initial_reskin_items: section_items(initial_items, true),
      initial_state: initial_state,
      grouped_custom_ingame: initial_state.ingame && initial_state.custom_only,
      panel_session: panel_session,
      payload_json:
        if(initial_state.ingame,
          do: nil,
          else:
            Jason.encode!(%{
              active_class: initial_state.active_class,
              initial_state: initial_state,
              items_by_class: items_by_class
            })
        ),
      asset_version: asset_version(),
      preload_images: preload_images(initial_items, initial_state.ingame),
      config_update: config_update
    }
  end

  defp initial_state(view, items_by_class) when is_binary(view) do
    case view |> String.trim() |> String.downcase() |> String.split("-", trim: true) do
      [requested_class | options] ->
        active_class = Map.get(@class_aliases, requested_class, requested_class)

        if Map.has_key?(items_by_class, active_class) do
          reverts_only = "reverts" in options

          %{
            active_class: active_class,
            custom_only: !reverts_only && "custom" in options,
            reverts_only: reverts_only,
            ingame: "ingame" in options
          }
        else
          default_state()
        end

      _ ->
        default_state()
    end
  end

  defp initial_state(_, _items_by_class), do: default_state()

  defp default_state do
    %{active_class: @active_class, custom_only: false, reverts_only: false, ingame: false}
  end

  defp initial_items(items_by_class, state) do
    items_by_class
    |> Map.get(state.active_class, [])
    |> Enum.filter(fn item ->
      cond do
        state.reverts_only -> !item.is_custom
        state.custom_only -> item.is_custom
        true -> true
      end
    end)
  end

  defp load_items_by_class do
    WeaponsConfig.items_by_class(@classes)
    |> Enum.into(%{}, fn {class_key, items} ->
      normalized_items =
        items
        |> Enum.map(&normalize_item(&1, class_key))
        |> Enum.sort_by(& &1.display_order)

      {class_key, normalized_items}
    end)
  end

  defp normalize_item(item, class_key) do
    effects =
      [
        effect_segment(item.positive, "positive"),
        effect_segment(item.neutral, "neutral"),
        effect_segment(item.negative, "negative")
      ]
      |> Enum.reject(&is_nil/1)

    title_segments = Enum.map(effects, & &1.text)
    type_level = type_level(item.weapon_type)

    %{
      name: item.name,
      uid: item.key,
      type_level: type_level,
      icon: icon_path(item.image, class_key),
      is_custom: item.type == "custom",
      is_hidden: item.hidden,
      is_reskin: item.reskin_only,
      is_all_class: item.all_class,
      display_order: display_order(item.reskin_only, item.all_class),
      purchase_key: item.points_store_purchase,
      title: title_text(item.name, title_segments),
      search:
        search_text(
          item.name,
          title_segments,
          item.type,
          item.weapon_type,
          item.points_store_purchase,
          item.reskin_only
        ),
      effects: effects
    }
  end

  defp panel_session(token, %{ingame: true, custom_only: true, active_class: class_key}) do
    class_id = Enum.find_value(@classes, &if(&1.key == class_key, do: &1.id))

    case WeaponPanel.fetch_session(token, class_id) do
      {:ok, session} -> session
      :error -> nil
    end
  end

  defp panel_session(_token, _state), do: nil

  defp mark_equipped(items, nil) do
    Enum.map(items, &Map.merge(&1, %{equipped: false, locked: false}))
  end

  defp mark_equipped(items, session) do
    Enum.map(items, fn item ->
      Map.merge(item, %{
        equipped: MapSet.member?(session.equipped_uids, item.uid),
        locked:
          item.purchase_key != "" &&
            MapSet.member?(session.locked_purchase_keys, item.purchase_key)
      })
    end)
  end

  defp section_items(items, reskin?) do
    items
    |> Enum.filter(&(&1.is_reskin == reskin?))
  end

  defp display_order(reskin?, all_class?) do
    if(reskin?, do: 2, else: 0) + if(all_class?, do: 1, else: 0)
  end

  defp search_text(
         name,
         title_segments,
         type,
         weapon_type,
         points_store_purchase,
         reskin_only
       ) do
    type_terms = if type == "custom", do: "custom cwx", else: type
    reskin_term = if reskin_only, do: " reskin", else: ""

    String.downcase(
      name <>
        " " <>
        Enum.join(title_segments, " ") <>
        " " <>
        type_terms <> " " <> weapon_type <> " " <> points_store_purchase <> reskin_term
    )
  end

  defp type_level(weapon_type) when is_binary(weapon_type) do
    case String.trim(weapon_type) do
      "" -> ""
      value -> "Level 1 " <> value
    end
  end

  defp effect_segment(value, class_name) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> %{text: String.replace(trimmed, ", ", "\n"), cls: class_name}
    end
  end

  defp title_text(name, effects) do
    case effects do
      [] -> name
      _ -> name <> ": " <> Enum.join(effects, "; ")
    end
  end

  defp icon_path(image, class_key) when is_binary(image) do
    case String.trim(image) do
      "" -> fallback_icon(class_key)
      filename -> "/info/icons/" <> filename
    end
  end

  defp icon_path(_, class_key), do: fallback_icon(class_key)

  defp fallback_icon(class_key),
    do: "/info/icons/" <> Map.get(@class_icons, class_key, "scout.png")

  defp preload_images(items, ingame) do
    class_images =
      if ingame, do: [], else: Enum.map(@classes, &("/info/icons/" <> &1.icon))

    item_images = Enum.map(items, & &1.icon)

    (class_images ++ item_images)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp asset_version do
    [
      "priv/static/info/css/changes.css",
      "priv/static/info/js/info_page.js",
      "priv/static/info/js/weapons_panel.js"
    ]
    |> Enum.flat_map(fn path ->
      case File.stat(Path.expand(path), time: :posix) do
        {:ok, %{mtime: mtime}} -> [mtime]
        _ -> []
      end
    end)
    |> Enum.max(fn -> System.system_time(:second) end)
    |> Integer.to_string()
  end

  defp config_update_metadata do
    [
      {"weapons.cfg", WeaponsConfig.config_path()}
    ]
    |> Enum.flat_map(fn {filename, path} ->
      case File.stat(path, time: :local) do
        {:ok, %{mtime: mtime}} -> [%{filename: filename, mtime: mtime}]
        _ -> []
      end
    end)
    |> Enum.max_by(& &1.mtime, fn -> nil end)
    |> case do
      nil ->
        nil

      %{filename: filename, mtime: mtime} ->
        formatted = format_mtime(mtime)

        %{
          label: "updated " <> formatted,
          title: filename <> " was updated " <> formatted
        }
    end
  end

  defp format_mtime({{year, month, day}, {hour, minute, second}}) do
    "#{pad2(day)} #{month_name(month)} #{year} #{pad2(second)}:#{pad2(minute)}:#{pad2(hour)}"
  end

  defp pad2(value), do: value |> Integer.to_string() |> String.pad_leading(2, "0")

  defp month_name(1), do: "January"
  defp month_name(2), do: "February"
  defp month_name(3), do: "March"
  defp month_name(4), do: "April"
  defp month_name(5), do: "May"
  defp month_name(6), do: "June"
  defp month_name(7), do: "July"
  defp month_name(8), do: "August"
  defp month_name(9), do: "September"
  defp month_name(10), do: "October"
  defp month_name(11), do: "November"
  defp month_name(12), do: "December"
end
