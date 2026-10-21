defmodule KogasaFrontendWeb.OnlineSummaryControllerTest do
  use KogasaFrontendWeb.ConnCase, async: false

  test "public playercount endpoint returns the current player count", %{conn: conn} do
    conn = get(conn, "/api/playercount")

    assert %{
             "success" => true,
             "player_count" => player_count,
             "visible_max" => visible_max,
             "display" => display,
             "updated" => updated
           } = json_response(conn, 200)

    assert is_integer(player_count) and player_count >= 0
    assert is_integer(visible_max) and visible_max > 0
    assert is_integer(updated) and updated > 0
    assert display == Integer.to_string(player_count)
    assert get_resp_header(conn, "access-control-allow-origin") == ["*"]

    assert get_resp_header(conn, "cache-control") == [
             "public, max-age=5, stale-while-revalidate=10"
           ]
  end

  test "legacy public summary uses only the API pipeline and creates no identity or session", %{
    conn: conn
  } do
    route =
      Phoenix.Router.route_info(
        KogasaFrontendWeb.Router,
        "GET",
        "/stats/online_summary.php",
        "localhost"
      )

    assert route.pipe_through == [:api]

    conn =
      conn |> put_req_header("accept", "application/json") |> get("/stats/online_summary.php")

    assert %{"success" => true, "player_count" => count, "display" => display} =
             json_response(conn, 200)

    assert is_integer(count) and count >= 0
    assert display == Integer.to_string(count)

    assert get_resp_header(conn, "cache-control") == [
             "public, max-age=5, stale-while-revalidate=10"
           ]

    assert get_resp_header(conn, "access-control-allow-origin") == ["*"]
    assert get_resp_header(conn, "x-content-type-options") == ["nosniff"]
    assert get_resp_header(conn, "set-cookie") == []
    refute Map.has_key?(conn.assigns, :chat_identity)
    refute Map.has_key?(conn.private, :plug_session)
    refute Map.has_key?(conn.private, :plug_session_info)
  end
end
