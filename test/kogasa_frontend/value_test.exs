defmodule KogasaFrontend.ValueTest do
  use ExUnit.Case, async: true

  alias KogasaFrontend.Value

  test "integer conversion truncates numeric values consistently" do
    assert Value.int(1.9) == 1
    assert Value.int(Decimal.new("1.9")) == 1
    assert Value.int(Decimal.new("-1.9")) == -1
    assert Value.int("1.9") == 1
  end

  test "truthy conversion is case-insensitive and trims strings" do
    for value <- [true, 1, "1", "true", " TRUE ", "yes", "ON"] do
      assert Value.truthy?(value)
    end

    for value <- [false, 0, nil, "", "false", "off"] do
      refute Value.truthy?(value)
    end
  end
end
