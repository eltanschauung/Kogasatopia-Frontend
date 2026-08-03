defmodule KogasaFrontend.Chat.NameStyleTest do
  use ExUnit.Case, async: true

  alias KogasaFrontend.Chat.NameStyle

  test "builds a gradient using SourceMod's MoreColors values" do
    assert NameStyle.from_preference(%{pattern: "gradient:blue:red", color: ""}) == %{
             kind: :gradient,
             first: "#99CCFF",
             second: "#FF4040"
           }
  end

  test "uses a valid pattern instead of the solid color" do
    assert NameStyle.from_preference(%{pattern: "america", color: "green"}) == %{
             kind: :america
           }
  end

  test "recognizes trans and rainbow presets" do
    assert NameStyle.from_preference(%{pattern: "trans", color: ""}) == %{kind: :trans}
    assert NameStyle.from_preference(%{pattern: "rainbow", color: ""}) == %{kind: :rainbow}
  end

  test "falls back to the solid color for an invalid pattern" do
    assert NameStyle.from_preference(%{pattern: "gradient:unknown:red", color: "green"}) == %{
             kind: :solid,
             color: "#3EFF3E"
           }
  end

  test "rejects unknown colors" do
    assert NameStyle.from_preference(%{pattern: "", color: "not-a-color"}) == nil
  end
end
