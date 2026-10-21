defmodule KogasaFrontend.PerformanceSqlTest do
  use ExUnit.Case, async: true

  test "production SQL has differential parity on isolated in-memory fixtures" do
    {output, status} =
      System.cmd(
        "python3",
        [
          Path.expand("../fixtures/performance_sql.py", __DIR__),
          KogasaFrontend.StatsFeed.weekly_killstreak_podium_sql(),
          KogasaFrontend.StatsFeed.aggregate_stats_sql(),
          KogasaFrontend.StatsFeed.log_rows_sql("l.player_count > 0")
        ],
        stderr_to_stdout: true
      )

    assert status == 0, output
    assert output =~ "fixture parity passed"
  end

  test "current-log source path skips counts and shares real row mapping/enrichment" do
    source = File.read!("lib/kogasa_frontend/stats_feed.ex")
    [_, current] = String.split(source, "  def current_log(", parts: 2)
    current = hd(String.split(current, "  def tab_hash"))
    assert current =~ "fetch_log_rows(\"l.player_count > 0\", [], 1, 0)"
    assert current =~ "attach_log_players(rows, identity_mode)"
    refute current =~ "COUNT"
    refute current =~ "case logs("
    [_, page] = String.split(source, "  def page_payload(", parts: 2)
    page = hd(String.split(page, "  @doc false"))
    assert page =~ "aggregate = aggregate_stats()"
    assert page =~ "summary(aggregate)"
    assert page =~ "performance_averages(aggregate)"
    refute page =~ "performance_averages()"
  end
end
