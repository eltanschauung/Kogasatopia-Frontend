defmodule KogasaFrontend.Chat.SteamProfilesTest do
  use ExUnit.Case, async: false

  alias KogasaFrontend.Chat.SteamProfiles

  @cache_table :kogasa_frontend_steam_profile_cache

  test "the supervised cache process owns the ETS table" do
    assert Process.whereis(SteamProfiles) == :ets.info(@cache_table, :owner)

    Task.async(fn -> SteamProfiles.fetch_cached_many(["76561198000000000"]) end)
    |> Task.await()

    assert Process.whereis(SteamProfiles) == :ets.info(@cache_table, :owner)
  end
end
