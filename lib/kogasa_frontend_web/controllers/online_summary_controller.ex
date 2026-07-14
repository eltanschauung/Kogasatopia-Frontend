defmodule KogasaFrontendWeb.OnlineSummaryController do
  use KogasaFrontendWeb, :controller

  alias KogasaFrontend.Online

  def index(conn, _params) do
    summary = Online.summary()
    payload = Map.put(summary, :display, "#{summary.player_count} / #{summary.visible_max}")

    conn
    |> put_resp_header("access-control-allow-origin", "*")
    |> put_resp_header("cache-control", "public, max-age=5, stale-while-revalidate=10")
    |> put_resp_header("x-content-type-options", "nosniff")
    |> json(payload)
  end
end
