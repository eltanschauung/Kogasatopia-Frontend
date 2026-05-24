defmodule WhaleChatWeb.LegacyControllerTest do
  use ExUnit.Case, async: false

  use WhaleChatWeb, :verified_routes

  import Plug.Conn, only: [get_resp_header: 2]
  import Phoenix.ConnTest

  @endpoint WhaleChatWeb.Endpoint

  setup do
    old_base = Application.get_env(:whale_chat, :legacy_php_base)
    Application.put_env(:whale_chat, :legacy_php_base, "http://127.0.0.1:9")

    on_exit(fn ->
      if old_base do
        Application.put_env(:whale_chat, :legacy_php_base, old_base)
      else
        Application.delete_env(:whale_chat, :legacy_php_base)
      end
    end)

    {:ok, conn: %{build_conn() | host: "localhost"}}
  end

  test "playercount widget returns 502 when php backend is unavailable", %{conn: conn} do
    conn = get(conn, "/playercount_widget/index.php")

    assert response(conn, 502) == "Legacy PHP backend unavailable"
    assert get_resp_header(conn, "location") == []
  end

  test "generic php passthrough does not redirect to localhost backend", %{conn: conn} do
    conn = get(conn, "/foo.php")

    assert response(conn, 502) == "Legacy PHP backend unavailable"
    assert get_resp_header(conn, "location") == []
  end
end
