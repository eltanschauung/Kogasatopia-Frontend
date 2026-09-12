defmodule KogasaFrontendWeb.InfoController do
  use KogasaFrontendWeb, :controller

  alias KogasaFrontend.InfoPage

  def entry(conn, params) do
    assigns = InfoPage.assigns(params["view"])

    conn
    |> put_root_layout(false)
    |> put_info_cache_headers(params["view"])
    |> render(:index, assigns)
  end

  defp put_info_cache_headers(conn, view) when is_binary(view) and view != "" do
    put_resp_header(conn, "cache-control", "no-store")
  end

  defp put_info_cache_headers(conn, _view) do
    put_resp_header(conn, "cache-control", "public, max-age=3600")
  end
end
