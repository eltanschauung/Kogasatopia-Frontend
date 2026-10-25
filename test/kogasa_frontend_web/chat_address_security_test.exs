defmodule KogasaFrontendWeb.ChatAddressSecurityTest do
  use KogasaFrontendWeb.ConnCase, async: false
  import Phoenix.LiveViewTest
  alias KogasaFrontendWeb.Plugs.ChatIdentity
  alias KogasaFrontend.Chat.IpBan

  test "HTTP and connected LiveView preserve both address families for ban policy", %{conn: conn} do
    for {peer, expected} <- [
          {{192, 0, 2, 23}, "192.0.0.0/16"},
          {{0x2001, 0xDB8, 0x1234, 0x5678, 1, 2, 3, 4}, "2001:db8:1234:5678::/64"},
          {{0, 0, 0, 0, 0, 65_535, 0xC000, 0x0217}, "192.0.0.0/16"}
        ] do
      conn = %{conn | remote_ip: peer} |> init_test_session(%{})
      http = ChatIdentity.call(conn, [])
      assert IpBan.subnet_for_actor(http.assigns.chat_identity) == expected

      {:ok, view, _} =
        conn
        |> Plug.Test.put_peer_data(%{address: peer, port: 1234, ssl_cert: nil})
        |> live("/chat")

      actor = :sys.get_state(view.pid).socket.assigns.identity
      assert actor.remote_ip == http.assigns.chat_identity.remote_ip
      assert IpBan.subnet_for_actor(actor) == expected
      GenServer.stop(view.pid)
    end
  end

  test "IPv4 and mapped IPv4 share the same canonical quota identity" do
    assert ChatIdentity.remote_ip_string({192, 0, 2, 23}) ==
             ChatIdentity.remote_ip_string({0, 0, 0, 0, 0, 65_535, 0xC000, 0x0217})

    assert ChatIdentity.remote_ip_string({1, 2}) == ""
  end
end
