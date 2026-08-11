defmodule KogasaFrontend.TimeDisplayTest do
  use ExUnit.Case, async: true

  alias KogasaFrontend.TimeDisplay

  test "formats server time in EST before daylight saving time starts" do
    assert TimeDisplay.format_server_datetime(1_709_449_199, "%Y-%m-%d %H:%M:%S %Z") ==
             "2024-03-03 01:59:59 EST"
  end

  test "formats server time in EDT during daylight saving time" do
    assert TimeDisplay.format_server_datetime(1_721_044_800, "%Y-%m-%d %H:%M:%S %Z") ==
             "2024-07-15 08:00:00 EDT"
  end

  test "invalid timestamps render as unavailable" do
    assert TimeDisplay.format_server_datetime(nil) == "n/a"
    assert TimeDisplay.server_hour(0) == nil
  end

  test "formats match log timestamps without a timezone suffix or leading hour zero" do
    assert TimeDisplay.format_server_match_datetime(1_786_428_720) ==
             "Aug 11, 2026 2:12 AM"
  end
end
