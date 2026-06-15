defmodule WhaleChatWeb.OnlineSummaryController do
  use WhaleChatWeb, :controller

  alias WhaleChat.Online

  def index(conn, _params) do
    conn
    |> put_resp_header("cache-control", "public, max-age=5")
    |> json(Online.summary())
  end
end
