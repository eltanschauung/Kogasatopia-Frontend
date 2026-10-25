defmodule KogasaFrontend.SteamSessionFailClosedTest do
  use ExUnit.Case, async: true
  alias KogasaFrontend.SteamSession

  test "legacy markers and malformed proofs never grant authentication without storage" do
    assert SteamSession.steamid(%{
             "steamid" => "10000000000000001",
             "steam_verified_id" => "10000000000000001"
           }) == nil

    refute SteamSession.valid?(nil, nil)
    refute SteamSession.valid?("bad", "bad")
    refute SteamSession.valid?(["bad"], %{})
  end
end
