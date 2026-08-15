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

  test "match logs expose typed sort values and the compact timestamp" do
    html =
      StatsFragments.current_log_fragment_html(%{
        map: "cp_badwater",
        started_at: 1_786_428_720,
        duration: 720,
        gamemode: "payload",
        players: [
          %{
            steamid: "76561198000000000",
            personaname: "A Long Player Name",
            kills: 12,
            deaths: 3,
            shots: 10,
            hits: 5,
            playtime: 600
          }
        ]
      })

    assert html =~ ~s(data-log-sortable)
    assert html =~ ~s(data-sort-type="text")
    assert html =~ ~s(data-sort-value="a long player name")
    assert html =~ ~s(data-sort-value="12")
    assert html =~ "cp_badwater |"
    assert html =~ "Aug 11, 2026 2:12 AM"
    refute html =~ "—"
    refute html =~ "12m"
  end

  test "empty filtered match logs explain that the search had no matches" do
    html = StatsFragments.logs_fragment_html(%{rows: [], q: "missing player"})

    assert html =~ "No logs match your search."
  end
end
