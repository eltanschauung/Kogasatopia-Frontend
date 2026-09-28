defmodule KogasaFrontend.CustomHatsConfig do
  @moduledoc false

  alias KogasaFrontend.ValveKeyValues

  @default_config_path "/home/kogasa/hlserver/tf2/tf/addons/sourcemod/configs/custom_hats.cfg"
  @default_image "100px-item_icon_nonomi_minigun.png"

  def names(path \\ config_path()) do
    catalog(path).names
  end

  def items(path \\ config_path()) do
    path
    |> ValveKeyValues.load_file()
    |> ValveKeyValues.section("CustomHats")
    |> ValveKeyValues.section("hats")
    |> List.wrap()
    |> Enum.flat_map(fn
      {hat_id, children} when is_list(children) ->
        if enabled?(children) and not forced?(children) do
          [
            %{
              id: hat_id,
              name: ValveKeyValues.value(children, "name", hat_id),
              slot: slot(children),
              image: ValveKeyValues.value(children, "image", @default_image),
              type: ValveKeyValues.value(children, "type", "Custom Hat"),
              level: level(children),
              classes: classes(children),
              points_store_purchase: ValveKeyValues.value(children, "points_store_purchase")
            }
          ]
        else
          []
        end

      _ ->
        []
    end)
  end

  def visible_for_class?(hat, class_key) do
    "all" in hat.classes or class_key in hat.classes
  end

  def catalog(path \\ config_path()) do
    path
    |> ValveKeyValues.load_file()
    |> ValveKeyValues.section("CustomHats")
    |> ValveKeyValues.section("hats")
    |> List.wrap()
    |> Enum.with_index()
    |> Enum.reduce(%{names: %{}, legacy_ids: %{}}, fn
      {{hat_id, children}, index}, catalog when is_list(children) ->
        name = ValveKeyValues.value(children, "name", hat_id)

        %{
          names: Map.put(catalog.names, hat_id, name),
          legacy_ids: Map.put(catalog.legacy_ids, Integer.to_string(index), hat_id)
        }

      _, catalog ->
        catalog
    end)
  end

  def config_path do
    Application.get_env(:kogasa_frontend, :custom_hats_config_path, @default_config_path)
  end

  defp enabled?(children) do
    ValveKeyValues.value(children, "enabled", "1") not in ["0", "false"]
  end

  defp forced?(children), do: ValveKeyValues.value(children, "force", "0") in ["1", "true"]

  defp slot(children) do
    children
    |> ValveKeyValues.value("slot", "default")
    |> String.downcase()
    |> case do
      "" -> "default"
      value -> value
    end
  end

  defp classes(children) do
    children
    |> ValveKeyValues.value("classes", "all")
    |> String.downcase()
    |> String.split([",", " ", "\t"], trim: true)
    |> Enum.map(fn
      "demo" -> "demoman"
      "engi" -> "engineer"
      value -> value
    end)
  end

  defp level(children) do
    case Integer.parse(ValveKeyValues.value(children, "level", "10")) do
      {value, ""} -> value
      _ -> 10
    end
  end
end
