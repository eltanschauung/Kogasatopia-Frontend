defmodule KogasaFrontendWeb.SteamLiveSessionSecurityTest do
  use KogasaFrontendWeb.ConnCase, async: false
  import Phoenix.LiveViewTest
  @moduletag :database
  alias KogasaFrontend.{Repo, SteamSession}
  alias KogasaFrontend.Chat.Message

  test "a connected socket revalidates its proof even without a logout notification", %{
    conn: conn
  } do
    id = "10000000000000001"
    {:ok, handle} = SteamSession.issue(id)

    session = %{
      "steamid" => id,
      "steam_session_id" => handle,
      "wt_chat_client_token" => "connected-session-test",
      "wt_chat_persona" => %{"display" => "Guest"}
    }

    {:ok, view, _html} = conn |> init_test_session(session) |> live("/chat")
    assert :ok = SteamSession.revoke(session)

    html =
      view |> element("#chat-form") |> render_submit(%{"message" => "stale authenticated send"})

    assert html =~ "Steam session expired. Please sign in again."
    assert Repo.aggregate(Message, :count) == 0
  end
end
