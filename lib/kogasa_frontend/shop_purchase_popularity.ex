defmodule KogasaFrontend.ShopPurchasePopularity do
  @moduledoc false

  alias KogasaFrontend.QueryResult
  alias KogasaFrontend.Repo
  alias KogasaFrontend.ValveKeyValues
  alias KogasaFrontend.Value

  @default_config_path "/home/kogasa/hlserver/tf2/tf/addons/sourcemod/configs/points_store.cfg"
  @query """
  SELECT item_key, COUNT(DISTINCT steamid64) AS purchasers
  FROM bonuspoints_transactions
  WHERE item_key <> '' AND steamid64 <> '' AND price_paid > 0
  GROUP BY item_key
  ORDER BY purchasers DESC, item_key ASC
  """

  def list(opts \\ []) do
    query = Keyword.get(opts, :query_fun, &Repo.query/1)
    path = Keyword.get(opts, :config_path, config_path())

    with {:ok, %{columns: columns, rows: rows}} <- query.(@query) do
      names = item_names(path)

      rows
      |> QueryResult.rows_to_maps(columns)
      |> Enum.map(fn row ->
        key = to_string(row["item_key"] || "")
        %{item_key: key, name: Map.get(names, key, key), purchasers: Value.int(row["purchasers"])}
      end)
    else
      _ -> []
    end
  rescue
    _ -> []
  end

  defp config_path do
    Application.get_env(:kogasa_frontend, :points_store_config_path, @default_config_path)
  end

  defp item_names(path) do
    path
    |> ValveKeyValues.load_file()
    |> ValveKeyValues.section("points_store")
    |> List.wrap()
    |> Enum.reduce(%{}, fn
      {key, children}, names when is_list(children) ->
        name = ValveKeyValues.value(children, "long_name", key)
        Map.put(names, key, if(name == "", do: key, else: name))

      _, names ->
        names
    end)
  end
end
