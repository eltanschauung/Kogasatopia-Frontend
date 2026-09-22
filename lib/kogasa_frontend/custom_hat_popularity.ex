defmodule KogasaFrontend.CustomHatPopularity do
  @moduledoc false

  alias KogasaFrontend.CustomHatsConfig

  @default_clientprefs_path "/home/kogasa/hlserver/tf2/tf/addons/sourcemod/data/sqlite/clientprefs-sqlite.sq3"

  @popularity_query """
  SELECT cc.value
  FROM sm_cookie_cache cc
  JOIN sm_cookies c ON c.id = cc.cookie_id
  WHERE c.name LIKE 'custom_hats_state%'
    AND cc.value <> ''
  ORDER BY cc.player ASC, c.name ASC;
  """

  def list(opts \\ []) do
    clientprefs_path =
      Keyword.get(opts, :clientprefs_path, configured_clientprefs_path())

    custom_hats_path =
      Keyword.get(opts, :custom_hats_path, CustomHatsConfig.config_path())

    with true <- File.regular?(clientprefs_path),
         sqlite3 when is_binary(sqlite3) <- System.find_executable("sqlite3"),
         {output, 0} <-
           System.cmd(
             sqlite3,
             [
               "-readonly",
               "-batch",
               "-noheader",
               "-separator",
               "\t",
               "-cmd",
               ".timeout 5000",
               clientprefs_path,
               @popularity_query
             ],
             stderr_to_stdout: true
           ) do
      catalog = CustomHatsConfig.catalog(custom_hats_path)
      parse_rows(output, catalog)
    else
      _ -> []
    end
  end

  defp configured_clientprefs_path do
    Application.get_env(
      :kogasa_frontend,
      :clientprefs_sqlite_path,
      @default_clientprefs_path
    )
  end

  defp parse_rows(output, catalog) do
    output
    |> String.split("\n", trim: true)
    |> Enum.flat_map(&hat_ids_from_cookie/1)
    |> Enum.map(fn hat_id -> Map.get(catalog.legacy_ids, hat_id, hat_id) end)
    |> Enum.filter(&Map.has_key?(catalog.names, &1))
    |> Enum.frequencies()
    |> Enum.filter(fn {_hat_id, equipped_clients} -> equipped_clients > 1 end)
    |> Enum.sort_by(fn {hat_id, equipped_clients} -> {-equipped_clients, hat_id} end)
    |> Enum.map(fn {hat_id, equipped_clients} ->
      %{
        hat_id: hat_id,
        name: Map.get(catalog.names, hat_id, hat_id),
        equipped_clients: equipped_clients
      }
    end)
  end

  defp hat_ids_from_cookie(value) do
    cond do
      String.contains?(value, "|") ->
        case String.split(value, "|", parts: 3) do
          [enabled, hat_id, _paint] when enabled != "0" and hat_id != "" -> [hat_id]
          _ -> []
        end

      String.contains?(value, ":") ->
        value
        |> String.split(",", trim: true)
        |> Enum.flat_map(fn entry ->
          case String.split(entry, ":", parts: 2) do
            [hat_id, _paint] when hat_id != "" -> [hat_id]
            _ -> []
          end
        end)

      true ->
        value
        |> String.split(",", trim: true)
        |> Enum.chunk_every(2, 2, :discard)
        |> Enum.map(&hd/1)
        |> Enum.reject(&(&1 == ""))
    end
  end
end
