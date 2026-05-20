defmodule WhaleChatWeb.InfoController do
  use WhaleChatWeb, :controller

  alias WhaleChat.InfoPage

  def entry(conn, _params) do
    case conn.request_path do
      "/info" ->
        conn
        |> put_no_store_headers()
        |> redirect(to: "/info/")

      _ ->
        assigns = InfoPage.assigns()

        conn
        |> put_root_layout(false)
        |> put_no_store_headers()
        |> render(:index, assigns)
    end
  end

  defp put_no_store_headers(conn) do
    conn
    |> put_resp_header("cache-control", "no-store, no-cache, must-revalidate, max-age=0")
    |> put_resp_header("pragma", "no-cache")
    |> put_resp_header("expires", "0")
    |> put_resp_header("surrogate-control", "no-store")
  end
end
