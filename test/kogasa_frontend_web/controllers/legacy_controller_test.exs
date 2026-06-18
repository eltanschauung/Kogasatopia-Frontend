defmodule KogasaFrontendWeb.LegacyControllerTest do
  use ExUnit.Case, async: false

  use KogasaFrontendWeb, :verified_routes

  import Plug.Conn, only: [get_resp_header: 2]
  import Phoenix.ConnTest

  @endpoint KogasaFrontendWeb.Endpoint

  setup do
    {:ok, conn: %{build_conn() | host: "localhost"}}
  end

  test "playercount widget renders natively", %{conn: conn} do
    conn = get(conn, "/playercount_widget/index.php")

    assert html_response(conn, 200) =~ ~s(<div class="server-name">Gensokyo | New Jersey</div>)
    assert response(conn, 200) =~ "https://bantculture.com/static/flags/us.png"
    assert get_resp_header(conn, "location") == []
  end

  test "playercount widget mge iframe renders natively", %{conn: conn} do
    conn = get(conn, "/playercount_widget/index3.php")

    assert html_response(conn, 200) =~ ~s(<div class="server-name">MGE Eientei | New Jersey</div>)
    assert response(conn, 200) =~ "https://bantculture.com/static/flags/kaguya.png"
    assert get_resp_header(conn, "location") == []
  end

  test "leaderboard app redirects to online", %{conn: conn} do
    conn = get(conn, "/leaderboard")

    assert redirected_to(conn, 302) == "/online"
  end

  test "legacy leaderboard php entrypoints redirect to online", %{conn: conn} do
    conn = get(conn, "/leaderboard/index.php")

    assert redirected_to(conn, 302) == "/online"
  end

  test "generic php passthrough returns not found", %{conn: conn} do
    conn = get(conn, "/foo.php")

    assert response(conn, 404) == "Not Found"
    assert get_resp_header(conn, "location") == []
  end
end
