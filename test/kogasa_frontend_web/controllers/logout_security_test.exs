defmodule KogasaFrontendWeb.LogoutSecurityTest do
  use KogasaFrontendWeb.ConnCase, async: false

  test "GET logout confirms without clearing authentication or notifying live sessions", %{
    conn: conn
  } do
    token = "synthetic-logout-test"

    Phoenix.PubSub.subscribe(
      KogasaFrontend.PubSub,
      KogasaFrontend.Chat.Identity.session_topic(token)
    )

    conn =
      conn
      |> init_test_session(%{"steamid" => "10000000000000001", "wt_chat_client_token" => token})
      |> get("/stats/login.php?action=logout&return=/chat")

    assert html_response(conn, 200) =~ "Are you sure"
    assert get_session(conn, "steamid") == "10000000000000001"
    refute conn.private[:plug_session_info] == :drop
    refute_receive :steam_logout
    assert get_resp_header(conn, "cache-control") == ["private, no-store"]
  end

  test "POST logout requires a real form-issued CSRF token", %{conn: conn} do
    for token <- [nil, "not-a-valid-token"] do
      assert_raise Plug.CSRFProtection.InvalidCSRFTokenError, fn ->
        params = if token, do: %{"_csrf_token" => token}, else: %{}

        conn
        |> init_test_session(%{})
        |> put_private(:plug_skip_csrf_protection, false)
        |> post("/stats/login.php", params)
      end
    end

    form = conn |> init_test_session(%{}) |> get("/stats/login.php?action=logout&return=/chat")
    [_, token] = Regex.run(~r/name="_csrf_token" value="([^"]+)"/, html_response(form, 200))

    result =
      form
      |> recycle()
      |> put_private(:plug_skip_csrf_protection, false)
      |> post("/stats/login.php", %{"_csrf_token" => token, "return" => "/chat"})

    assert redirected_to(result) == "/chat"
    assert result.private[:plug_session_info] == :drop
  end
end
