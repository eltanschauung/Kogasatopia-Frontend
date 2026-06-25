defmodule KogasaFrontendWeb.MapsDbApiController do
  use KogasaFrontendWeb, :controller

  alias KogasaFrontend.MapsDb

  def handle(conn, params) do
    action = params["action"] || conn.body_params["action"] || "list"
    dispatch(conn, action, params)
  end

  defp dispatch(conn, "list", _params) do
    json(conn, %{maps: MapsDb.list_api_maps()})
  end

  defp dispatch(conn, "load", params) do
    case MapsDb.load_config_file(params["map"], params["source"]) do
      {:ok, payload} -> json(conn, payload)
      {:error, reason} -> mapsdb_reason(conn, reason)
    end
  end

  defp dispatch(conn, _action, _params), do: json_error(conn, 400, "Unsupported action")

  defp mapsdb_reason(conn, :missing_map), do: json_error(conn, 400, "Missing map parameter")
  defp mapsdb_reason(conn, :invalid_map), do: json_error(conn, 400, "Invalid map name")
  defp mapsdb_reason(conn, :invalid_source), do: json_error(conn, 400, "Invalid config source")
  defp mapsdb_reason(conn, :not_found), do: json_error(conn, 404, "Map config not found")
  defp mapsdb_reason(conn, {:io, _}), do: json_error(conn, 500, "Unable to process file")
  defp mapsdb_reason(conn, _), do: json_error(conn, 500, "Server error")

  defp json_error(conn, status, message) do
    conn
    |> put_status(status)
    |> json(%{error: message})
  end
end
