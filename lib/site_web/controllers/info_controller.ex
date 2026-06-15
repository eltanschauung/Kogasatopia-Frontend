defmodule WhaleChatWeb.InfoController do
  use WhaleChatWeb, :controller

  alias WhaleChat.InfoPage

  def entry(conn, _params) do
    assigns = InfoPage.assigns()

    conn
    |> put_root_layout(false)
    |> put_info_cache_headers()
    |> render(:index, assigns)
  end

  defp put_info_cache_headers(conn) do
    put_resp_header(conn, "cache-control", "public, max-age=3600")
  end
end
