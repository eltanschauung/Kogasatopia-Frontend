defmodule KogasaFrontendWeb.OnlineSummaryController do
  use KogasaFrontendWeb, :controller

  alias KogasaFrontend.Online

  def index(conn, _params) do
    conn
    |> put_resp_header("cache-control", "public, max-age=5")
    |> json(Online.summary())
  end
end
