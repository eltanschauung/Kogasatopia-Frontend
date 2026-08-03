defmodule KogasaFrontend.DisplayFormatTest do
  use ExUnit.Case, async: true

  alias KogasaFrontend.DisplayFormat

  test "formats numeric values consistently" do
    assert DisplayFormat.integer(1_234_567) == "1,234,567"
    assert DisplayFormat.decimal("12.345", 2) == "12.35"
    assert DisplayFormat.signed_decimal(2.5, 1) == "+2.5"
    assert DisplayFormat.signed_decimal(-2.5, 1) == "-2.5"
  end

  test "formats compact durations" do
    assert DisplayFormat.duration(0) == "0m"
    assert DisplayFormat.duration(59) == "0m"
    assert DisplayFormat.duration(3600) == "1h"
    assert DisplayFormat.duration(3660) == "1h 1m"
  end

  test "supports match-log duration presentation" do
    assert DisplayFormat.duration(nil, minimum_minutes: 1, show_zero_minutes: true) == "0m"
    assert DisplayFormat.duration(10, minimum_minutes: 1, show_zero_minutes: true) == "1m"
    assert DisplayFormat.duration(3600, minimum_minutes: 1, show_zero_minutes: true) == "1h 0m"
  end
end
