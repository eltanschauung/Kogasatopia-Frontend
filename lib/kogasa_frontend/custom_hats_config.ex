defmodule KogasaFrontend.CustomHatsConfig do
  @moduledoc false

  alias KogasaFrontend.ValveKeyValues

  @default_config_path "/home/kogasa/hlserver/tf2/tf/addons/sourcemod/configs/custom_hats.cfg"

  def names(path \\ config_path()) do
    catalog(path).names
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
end
