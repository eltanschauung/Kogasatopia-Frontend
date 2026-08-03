defmodule KogasaFrontend.ValueTest do
  use ExUnit.Case, async: true

  alias KogasaFrontend.Value

  test "integer conversion truncates numeric values consistently" do
    assert Value.int(1.9) == 1
    assert Value.int(Decimal.new("1.9")) == 1
    assert Value.int(Decimal.new("-1.9")) == -1
    assert Value.int("1.9") == 1
  end
end
