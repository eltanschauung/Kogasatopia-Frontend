defmodule KogasaFrontend.SteamSessionTest do
  use KogasaFrontendWeb.ConnCase, async: false
  @moduletag :database
  import Ecto.Query
  alias KogasaFrontend.{Chat, Repo, SteamSession}
  alias KogasaFrontend.SteamSession.Record
  alias KogasaFrontend.Chat.Identity
  alias KogasaFrontendWeb.{ChatApiController, ChatLive, SteamLogin}
  @id "10000000000000001"
  @persona %{"display" => "Guest"}
  @opts [login_path: "/stats/login.php", default_return: "/stats"]

  defp session(id \\ @id) do
    {:ok, handle} = SteamSession.issue(id)

    %{
      "steamid" => id,
      "steam_session_id" => handle,
      "wt_chat_client_token" => "browser-#{System.unique_integer([:positive])}",
      "wt_chat_persona" => @persona
    }
  end

  test "only digests persist and each device has an independently revocable proof" do
    first = session()
    second = session()
    assert SteamSession.steamid(first) == @id
    assert SteamSession.steamid(second) == @id
    records = Repo.all(Record)
    assert length(records) == 2
    refute inspect(records) =~ first["steam_session_id"]
    assert Enum.all?(records, &(byte_size(&1.token_hash) == 64))
    assert :ok = SteamSession.revoke(first)
    assert SteamSession.steamid(first) == nil
    assert SteamSession.steamid(second) == @id
    assert :ok = SteamSession.revoke(first)
  end

  test "marker-only, missing, malformed and cross-account handles fail closed" do
    s = session()

    for invalid <- [
          Map.delete(s, "steam_session_id"),
          Map.put(s, "steam_session_id", String.duplicate("a", 43)),
          Map.put(s, "steam_session_id", ["wrong-type"]),
          Map.put(s, "steamid", "10000000000000002")
        ] do
      assert SteamSession.steamid(invalid) == nil
    end
  end

  test "absolute expiry is checked in storage and pruning leaves active devices alone" do
    expired = session()
    active = session("10000000000000002")

    Repo.update_all(from(s in Record, where: s.steamid == ^@id),
      set: [expires_at: System.system_time(:second) - 1]
    )

    assert SteamSession.steamid(expired) == nil
    assert {:ok, 1} = SteamSession.prune_expired()
    assert SteamSession.steamid(active) == "10000000000000002"
    assert Repo.aggregate(Record, :count) == 1
  end

  test "successful same-device login replacement revokes only the old handle" do
    previous = session()
    independent = session()
    assert {:ok, replacement} = SteamSession.issue("10000000000000002", previous)
    assert SteamSession.steamid(previous) == nil
    assert SteamSession.valid?("10000000000000002", replacement)
    assert SteamSession.steamid(independent) == @id
    assert {:error, :invalid} = SteamSession.issue("invalid", independent)
    assert SteamSession.steamid(independent) == @id
  end

  test "copied signed cookie loses authority after protected logout", %{conn: conn} do
    s = session()
    form = conn |> init_test_session(s) |> get("/stats/login.php?action=logout&return=/chat")
    assert SteamSession.steamid(get_session(form)) == @id
    [_, token] = Regex.run(~r/name="_csrf_token" value="([^"]+)"/, html_response(form, 200))

    result =
      form
      |> recycle()
      |> put_private(:plug_skip_csrf_protection, false)
      |> post("/stats/login.php", %{"_csrf_token" => token, "return" => "/chat"})

    assert redirected_to(result) == "/chat"
    replay = form |> recycle() |> get("/chat")
    assert html_response(replay, 200) =~ "WhaleChat"
    assert replay.assigns.chat_identity.steamid == nil
    assert SteamSession.steamid(s) == nil
  end

  test "missed PubSub logout cannot authorize an existing LiveView or direct chat action" do
    s = session()
    actor = Identity.from_session(s, @persona)
    assert :ok = SteamSession.revoke(s)
    assert {:error, :authentication_expired} = Chat.submit_message(actor, "Still here")
    assert {:error, :authentication_expired} = Chat.create_chat_message(actor, "Still here")
    socket = %Phoenix.LiveView.Socket{assigns: %{identity: actor, __changed__: %{}}}

    assert {:noreply, result} =
             ChatLive.handle_event("send", %{"message" => "Still here"}, socket)

    assert result.assigns.identity.steamid == nil
    assert result.assigns.identity.steam_session_id == nil
    assert result.assigns.status =~ "sign in"

    assert {:ok, mounted} =
             ChatLive.mount(%{}, s, %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}}})

    assert mounted.assigns.identity.steamid == nil

    api =
      Plug.Test.conn(:post, "/stats/chat.php", %{"message" => "Still here"})
      |> assign(:chat_identity, actor)
      |> ChatApiController.create(%{})

    assert api.status == 401
  end

  test "unavailable registry neither accepts a proof nor falsely confirms logout" do
    s = session()
    previous = Repo.get_dynamic_repo()
    Repo.put_dynamic_repo(:deliberately_unavailable_audit_repo)

    try do
      assert SteamSession.steamid(s) == nil
      assert {:error, :unavailable} = SteamSession.issue(@id)
      assert {:error, :unavailable} = SteamSession.revoke(s)
      conn = Plug.Test.conn(:post, "/stats/login.php") |> init_test_session(s)
      response = SteamLogin.handle(conn, %{"action" => "logout"}, @opts)
      assert response.status == 503
      refute response.private[:plug_session_info] == :drop
      refute response.resp_body =~ s["steam_session_id"]
    after
      Repo.put_dynamic_repo(previous)
    end

    assert SteamSession.steamid(s) == @id
  end
end
