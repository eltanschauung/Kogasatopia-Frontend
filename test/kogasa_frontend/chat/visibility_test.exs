defmodule KogasaFrontend.Chat.VisibilityTest do
  use ExUnit.Case, async: true
  alias KogasaFrontend.Chat.Visibility

  @hidden ["76561198000000001", "76561198000000002"]

  test "both hidden accounts can intentionally post as authenticated web users" do
    for id <- @hidden do
      row = %{steamid: id, iphash: "web-browser-hash", server_ip: "192.0.2.1"}
      assert Visibility.visible?(row, @hidden)
      assert Visibility.visible?(Map.new(row, fn {k, v} -> {Atom.to_string(k), v} end), @hidden)
    end
  end

  test "passive game messages, relays and system announcements remain hidden" do
    for id <- @hidden do
      refute Visibility.visible?(%{steamid: id, iphash: nil, server_ip: nil}, @hidden)

      refute Visibility.visible?(
               %{steamid: id, iphash: "system", server_ip: "192.0.2.1"},
               @hidden
             )

      refute Visibility.visible?(%{steamid: id, iphash: "web", server_ip: nil}, @hidden)

      for steamid <- [id, nil, "76561198000000003"] do
        refute Visibility.visible?(
                 %{steamid: steamid, iphash: "player:" <> id, server_ip: "192.0.2.1"},
                 @hidden
               )
      end
    end
  end

  test "other accounts and anonymous messages retain their existing visibility" do
    assert Visibility.visible?(%{steamid: "76561198000000003"}, @hidden)
    assert Visibility.visible?(%{steamid: nil, iphash: "guest", server_ip: "192.0.2.1"}, @hidden)
    assert Visibility.visible?(%{steamid: nil, iphash: "system"}, @hidden)
    assert Visibility.visible?(%{steamid: hd(@hidden)}, [])
  end
end
