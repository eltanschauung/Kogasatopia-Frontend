defmodule KogasaFrontend.PlayerPresentationTest do
  use ExUnit.Case, async: true

  alias KogasaFrontend.PlayerPresentation

  test "custom name styles take priority over the admin class" do
    attrs =
      PlayerPresentation.name_attributes(
        %{kind: :solid, color: "#abcdef"},
        true,
        ["player-name"]
      )

    assert attrs.classes == "player-name"
    assert attrs.style == "color: #abcdef"
    assert attrs.title == "Admin"
  end

  test "plain admins retain the admin class" do
    assert %{classes: "player-name admin-name", style: nil, title: "Admin"} =
             PlayerPresentation.name_attributes(nil, true, ["player-name"])
  end

  test "builds Steam profile and country flag metadata" do
    assert PlayerPresentation.steam_profile_url("76561198101141877") ==
             "https://steamcommunity.com/profiles/76561198101141877"

    assert %{code: "ca", name: "Canada", url: url} =
             PlayerPresentation.country_flag("CA", "Canada")

    assert String.ends_with?(url, "/ca.png")
    assert PlayerPresentation.country_flag("../CA", "Canada").code == "ca"
  end
end
