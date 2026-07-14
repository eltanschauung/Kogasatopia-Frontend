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
end
