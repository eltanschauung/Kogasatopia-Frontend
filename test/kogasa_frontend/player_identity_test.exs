defmodule KogasaFrontend.PlayerIdentityTest do
  use ExUnit.Case, async: true

  alias KogasaFrontend.PlayerIdentity

  test "resolves a prename before cached and API names" do
    identity = %{prename: "Preferred", cached_name: "Cached"}

    assert PlayerIdentity.resolve_name(identity, "Steam API", "Recorded", "7656") == "Preferred"
  end

  test "resolves a cached name before an API name" do
    identity = %{prename: "", cached_name: "Cached"}

    assert PlayerIdentity.resolve_name(identity, "Steam API", "Recorded", "7656") == "Cached"
  end

  test "uses the API and recorded names only as fallbacks" do
    identity = PlayerIdentity.empty()

    assert PlayerIdentity.resolve_name(identity, "Steam API", "Recorded", "7656") == "Steam API"
    assert PlayerIdentity.resolve_name(identity, "", "Recorded", "7656") == "Recorded"
    assert PlayerIdentity.resolve_name(identity, "", "", "7656") == "7656"
  end

  test "stats Steam mode ignores prenames and custom styles" do
    identity = %{
      prename: "Preferred",
      cached_name: "Cached",
      name_style: %{kind: :rainbow}
    }

    assert PlayerIdentity.stats_mode() == :steam

    assert PlayerIdentity.resolve_name(identity, "Steam API", "Recorded", "7656", :steam) ==
             "Cached"

    assert PlayerIdentity.name_style(identity, :steam) == nil
    assert PlayerIdentity.name_style(identity, :filters) == %{kind: :rainbow}
  end
end
