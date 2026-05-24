defmodule WhaleChatWeb.PageControllerTest do
  use WhaleChatWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Gensokyo New Jersey"
  end
end
