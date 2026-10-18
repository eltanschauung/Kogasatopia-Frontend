defmodule KogasaFrontend.SteamChatTest do
  use ExUnit.Case, async: false
  import Plug.Conn
  import ExUnit.CaptureLog
  alias KogasaFrontend.Chat
  alias KogasaFrontend.Chat.{HourlyQuota, Identity, NameStyle, RateLimiter, Sender, SourceName}
  alias KogasaFrontend.SteamSession
  alias KogasaFrontendWeb.{ChatApiController, ChatLive, SteamLogin}
  alias KogasaFrontendWeb.Plugs.ChatIdentity

  @id "10000000000000001"
  @persona %{"display" => "{gold}[Web]{default} Guest"}
  @opts [login_path: "/stats/login.php", default_return: "/stats"]

  defp session do
    %{
      "steamid" => @id,
      "steam_verified_id" => @id,
      "wt_chat_client_token" => "test-#{System.unique_integer([:positive])}",
      "wt_chat_persona" => @persona
    }
  end

  defp conn(session \\ %{}),
    do: Plug.Test.conn(:get, "/stats/login.php") |> Plug.Test.init_test_session(session)

  test "only matching server-verified sessions have an authenticated chat identity" do
    s = session()
    assert SteamSession.steamid(s) == @id
    assert Identity.from_session(s, @persona).steamid == @id

    for invalid <- [
          Map.delete(s, "steam_verified_id"),
          Map.put(s, "steamid", "10000000000000002"),
          Map.put(s, "steamid", "bad")
        ] do
      assert SteamSession.steamid(invalid) == nil
      identity = Identity.from_session(invalid, @persona)
      assert identity.steamid == nil
      assert identity.personaname == @persona["display"]
    end
  end

  test "HTTP and LiveView use exactly the same authenticated identity and browser token" do
    s = session()
    plug = ChatIdentity.call(conn(s), [])
    socket = %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}}}
    assert {:ok, mounted} = ChatLive.mount(%{}, s, socket)

    for key <- [:steamid, :personaname, :iphash, :rate_key, :browser_key] do
      assert mounted.assigns.identity[key] == plug.assigns.chat_identity[key]
    end

    assert mounted.assigns.identity.steamid == @id
    assert mounted.assigns.identity.personaname == nil
  end

  test "a raw SteamID parameter cannot log in or change a verified account" do
    response = SteamLogin.handle(conn(), %{"steamid" => @id}, @opts)
    assert response.status == 302

    assert get_resp_header(response, "location")
           |> hd()
           |> String.starts_with?("https://steamcommunity.com/openid/login?")

    assert get_session(response, "steamid") == nil
    assert get_session(response, "steam_verified_id") == nil
  end

  defp challenge do
    started = SteamLogin.handle(conn(), %{"return" => "/chat"}, @opts)

    provider =
      get_resp_header(started, "location")
      |> hd()
      |> URI.parse()
      |> Map.fetch!(:query)
      |> URI.decode_query()

    returned = provider["openid.return_to"]
    state = URI.parse(returned).query |> URI.decode_query() |> Map.fetch!("state")
    claim = "https://steamcommunity.com/openid/id/" <> @id

    params = %{
      "return" => "/chat",
      "state" => state,
      "openid.mode" => "id_res",
      "openid.ns" => "http://specs.openid.net/auth/2.0",
      "openid.op_endpoint" => "https://steamcommunity.com/openid/login",
      "openid.claimed_id" => claim,
      "openid.identity" => claim,
      "openid.return_to" => returned,
      "openid.response_nonce" => "test-provider-nonce",
      "openid.signed" => "op_endpoint,claimed_id,identity,return_to,response_nonce"
    }

    {get_session(started), params}
  end

  test "successful provider verification creates the shared verified identity" do
    {s, params} = challenge()

    Req.Test.stub(__MODULE__, fn request ->
      request = Plug.Parsers.call(request, Plug.Parsers.init(parsers: [:urlencoded]))
      assert request.method == "POST"
      assert request.body_params["openid.mode"] == "check_authentication"
      Req.Test.text(request, "ns:http://specs.openid.net/auth/2.0\nis_valid:true\n")
    end)

    response =
      SteamLogin.handle(
        conn(s),
        params,
        @opts ++ [request_options: [plug: {Req.Test, __MODULE__}]]
      )

    assert response.status == 302
    assert get_resp_header(response, "location") == ["/chat"]
    assert SteamSession.steamid(get_session(response)) == @id
    assert get_session(response, "steam_login_pending") == nil
  end

  test "unbound, expired, unsigned and mismatched callbacks never issue verified identity" do
    {s, params} = challenge()

    cases = [
      {%{}, params},
      {s, Map.put(params, "state", "wrong")},
      {put_in(s, ["steam_login_pending", "issued_at"], 0), params},
      {s, Map.put(params, "openid.signed", "identity")},
      {s, Map.put(params, "openid.signed", ["identity"])},
      {s, Map.put(params, "openid.return_to", "https://example.com/")},
      {s, Map.put(params, "openid.identity", "https://example.com/")}
    ]

    for {state, payload} <- cases do
      response = SteamLogin.handle(conn(state), payload, @opts)
      assert SteamSession.steamid(get_session(response)) == nil
    end
  end

  test "provider rejection cannot authenticate and logout drops the verified session" do
    {s, params} = challenge()
    Req.Test.stub(__MODULE__, &Req.Test.text(&1, "is_valid:false\n"))

    rejected =
      SteamLogin.handle(
        conn(s),
        params,
        @opts ++ [request_options: [plug: {Req.Test, __MODULE__}]]
      )

    assert SteamSession.steamid(get_session(rejected)) == nil
    logged_out = SteamLogin.handle(conn(session()), %{"action" => "logout"}, @opts)
    assert logged_out.private.plug_session_info == :drop
  end

  test "authenticated hourly quota permits ten but not eleven and follows the account" do
    actor = Identity.from_session(session(), @persona)
    # Unique account avoids interference with other quota tests.
    actor = %{actor | steamid: "quota-#{System.unique_integer([:positive])}"}
    quota = HourlyQuota.policy(actor)
    assert quota.limit == 10

    assert Enum.all?(1..10, fn _ ->
             RateLimiter.allow_count?(quota.keys, quota.limit, quota.window)
           end)

    refute RateLimiter.allow_count?(quota.keys, quota.limit, quota.window)
    moved = Map.merge(actor, %{browser_key: "other-browser", remote_ip: "192.0.2.20"})
    assert RateLimiter.at_count_limit?(HourlyQuota.policy(moved).keys, 10, 3600)
    assert HourlyQuota.policy(%{}).limit == 5
  end

  test "HTTP and LiveView return the authenticated ten-hourly limit warning" do
    actor = Identity.from_session(session(), @persona)
    quota = HourlyQuota.policy(actor)
    Enum.each(1..10, fn _ -> RateLimiter.allow_count?(quota.keys, 10, 3600) end)

    api =
      Plug.Test.conn(:post, "/stats/chat.php", %{"message" => "Hello there"})
      |> assign(:chat_identity, actor)
      |> ChatApiController.create(%{})

    assert api.status == 429
    assert Jason.decode!(api.resp_body)["message"] =~ "10/hour"
    socket = %Phoenix.LiveView.Socket{assigns: %{identity: actor, __changed__: %{}}}

    assert {:noreply, socket} =
             ChatLive.handle_event("send", %{"message" => "Hello there"}, socket)

    assert socket.assigns.status =~ "10/hour"
  end

  test "chat API requires CSRF even with an authenticated cookie, and accepts the form's token" do
    s =
      session()
      |> Map.put("steamid", "10000000000000003")
      |> Map.put("steam_verified_id", "10000000000000003")

    quota = s |> Identity.from_session(@persona) |> HourlyQuota.policy()
    Enum.each(1..10, fn _ -> RateLimiter.allow_count?(quota.keys, 10, 3600) end)

    request = fn state ->
      Plug.Test.conn(:post, "/stats/chat.php", %{"message" => "Hello"})
      |> Plug.Test.init_test_session(state)
      |> put_req_header("accept", "application/json")
    end

    error =
      assert_raise Plug.Conn.WrapperError, fn ->
        KogasaFrontendWeb.Router.call(request.(s), KogasaFrontendWeb.Router.init([]))
      end

    assert %Plug.CSRFProtection.InvalidCSRFTokenError{} = error.reason
    token = Plug.CSRFProtection.get_csrf_token()
    s = Map.put(s, "_csrf_token", Plug.CSRFProtection.dump_state())

    capture_log(fn ->
      response =
        request.(s)
        |> put_req_header("x-csrf-token", token)
        |> KogasaFrontendWeb.Router.call(KogasaFrontendWeb.Router.init([]))

      assert response.status == 429
      assert Jason.decode!(response.resp_body)["message"] =~ "10/hour"
    end)
  end

  test "logout downgrades already-open chat sockets without changing their guest persona" do
    s = session()
    actor = s |> Identity.from_session(@persona)
    Phoenix.PubSub.subscribe(KogasaFrontend.PubSub, Identity.session_topic(actor.browser_key))
    SteamLogin.handle(conn(s), %{"action" => "logout"}, @opts)
    assert_receive :steam_logout
    socket = %Phoenix.LiveView.Socket{assigns: %{identity: actor, __changed__: %{}}}
    assert {:noreply, socket} = ChatLive.handle_info(:steam_logout, socket)
    assert socket.assigns.identity.steamid == nil
    assert socket.assigns.identity.personaname == @persona["display"]
    assert socket.assigns.identity.rate_key == actor.browser_key
  end

  test "prename and pattern override cached/API names while the Steam avatar remains attached" do
    style = NameStyle.from_preference(%{color: "green", pattern: "gradient:blue:red"})
    profile = %{"personaname" => "Steam Name", "avatarfull" => "https://example.com/avatar.jpg"}
    stored = %{prename: "Chosen Name", cached_name: "Cached Name", name_style: style}
    sender = Sender.presentation(%{steamid: @id}, profile, stored)
    assert sender.display_name == "Chosen Name"
    assert String.starts_with?(sender.relay_name, "{gold}[Web]{default} ")
    assert String.ends_with?(sender.relay_name, "{default}")
    refute sender.relay_name =~ " | Web"
    assert sender.relay_name =~ "\x0799CCFF"
    assert sender.relay_name =~ "\x07FF4040"

    row = %{
      id: 1,
      steamid: @id,
      iphash: "test",
      server_ip: "192.0.2.1",
      personaname: sender.display_name,
      message: "Hi",
      alert: true
    }

    payload = Chat.message_payload(row, %{@id => profile}, %{@id => style})
    assert payload.name == sender.display_name
    assert payload.clan_tag == "{gold}[Web]{default}"
    assert payload.name_style == style
    assert payload.avatar == profile["avatarfull"]
    assert payload.steamid == @id
  end

  test "missing prenames fall back to cached then Steam names; anonymous personas are unchanged" do
    actor = %{steamid: @id}
    profile = %{"personaname" => "Steam Name"}

    assert Sender.presentation(actor, profile, %{cached_name: "Saved"}).display_name ==
             "Saved"

    assert Sender.presentation(actor, profile, %{}).display_name == "Steam Name"
    assert Sender.presentation(actor, nil, %{}).display_name == @id

    assert Sender.presentation(%{personaname: "{green}Guest"}, nil, %{}).relay_name ==
             "{green}Guest"
  end

  test "Source relay patterns match Filters, reset colors and fit its byte budget" do
    for pattern <- [
          "america",
          "map",
          "trans",
          "rainbow",
          "gradient:blue:red:75",
          "gradient3:blue:white:red"
        ] do
      style = NameStyle.from_preference(%{pattern: pattern})
      rendered = SourceName.render(String.duplicate("人", 40), style)
      assert String.valid?(rendered)
      assert String.ends_with?(rendered, "\x01")
      assert byte_size(rendered <> " | Web") < 128
      assert rendered =~ "\x07"

      for name <- [String.duplicate("人", 40), String.duplicate("a", 40)] do
        sender = Sender.presentation(%{steamid: @id}, nil, %{prename: name, name_style: style})
        assert String.valid?(sender.relay_name)
        assert byte_size(sender.relay_name) < 128
        assert String.ends_with?(sender.relay_name, "{default}")
      end
    end

    assert SourceName.render("ABC", %{kind: :trans}) == "\x075BCEFAA\x07FFFFFFB\x07F5A9B8C\x01"
  end
end
