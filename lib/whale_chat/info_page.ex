defmodule WhaleChat.InfoPage do
  @moduledoc false

  alias WhaleChat.Tf2Classes
  alias WhaleChat.WeaponRevertsConfig

  @active_class "scout"
  @classes Tf2Classes.info_classes()
  @class_icons Map.new(@classes, fn %{key: key, icon: icon} -> {key, icon} end)

  def assigns do
    items_by_class = load_items_by_class()
    preload_images = preload_images(items_by_class)

    %{
      classes: @classes,
      active_class: @active_class,
      initial_items: Map.get(items_by_class, @active_class, []),
      payload_json: Jason.encode!(%{active_class: @active_class, items_by_class: items_by_class}),
      preload_images: preload_images
    }
  end

  defp load_items_by_class do
    WeaponRevertsConfig.items_by_class(@classes)
    |> Enum.into(%{}, fn {class_key, items} ->
      {class_key, Enum.map(items, &normalize_item(&1, class_key))}
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

    %{
      name: item.name,
      icon: icon_path(item.image, class_key),
      title: title_text(item.name, title_segments),
      search:
        String.downcase(item.name <> " " <> Enum.join(title_segments, " ") <> " " <> item.type),
      effects: effects
    }
  end

  defp effect_segment(value, class_name) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> %{text: trimmed, cls: class_name}
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

  defp preload_images(items_by_class) do
    class_images =
      Enum.map(@classes, fn %{icon: icon} -> "/info/icons/" <> icon end)

    item_images =
      items_by_class
      |> Map.values()
      |> List.flatten()
      |> Enum.map(& &1.icon)

    (class_images ++ item_images)
    |> Enum.uniq()
    |> Enum.sort()
  end
end
