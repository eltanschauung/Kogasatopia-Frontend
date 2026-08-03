defmodule KogasaFrontendWeb.StatsFragmentsTest do
  use ExUnit.Case, async: true

  alias KogasaFrontendWeb.StatsFragments

  test "custom player styles replace the admin class without hiding admin status" do
    html =
      StatsFragments.cumulative_rows_html([
        %{
          steamid: "76561198000000000",
          personaname: "Styled Admin",
          profileurl: "https://steamcommunity.com/profiles/76561198000000000",
          is_admin: true,
          name_style: %{kind: :gradient, first: "#99CCFF", second: "#FF4040"}
        }
      ])

    assert html =~ "chat-name-gradient"
    assert html =~ ~s(title="Admin")
    assert html =~ "--chat-name-gradient"
    refute html =~ "admin-name"
  end

  test "admins without a custom style retain the admin class" do
    html =
      StatsFragments.cumulative_rows_html([
        %{
          steamid: "76561198000000000",
          personaname: "Admin",
          is_admin: true,
          name_style: nil
        }
      ])

    assert html =~ "admin-name"
    assert html =~ ~s(title="Admin")
  end
end
