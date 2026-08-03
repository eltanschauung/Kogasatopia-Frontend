defmodule KogasaFrontendWeb.OnlineApiController do
  use KogasaFrontendWeb, :controller

  alias KogasaFrontend.{OnlineFeed, PlayerIdentity}

  def index(conn, params) do
    identity_mode =
      if Map.get(params, "identity") == "stats", do: PlayerIdentity.stats_mode(), else: :filters

    payload = OnlineFeed.payload(%{identity_mode: identity_mode})

    conn
    |> put_resp_header("cache-control", "no-store, no-cache, must-revalidate, max-age=0")
    |> put_resp_header("pragma", "no-cache")
    |> maybe_status(payload)
    |> json(payload)
  end

  defp maybe_status(conn, %{"success" => false}), do: put_status(conn, 500)
  defp maybe_status(conn, _), do: conn
end
