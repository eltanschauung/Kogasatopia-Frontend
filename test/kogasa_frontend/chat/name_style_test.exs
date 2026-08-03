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

  test "renders the MAP flag preset with the SourceMod palette" do
    style = NameStyle.from_preference(%{pattern: "map", color: ""})

    assert style == %{kind: :map}
    assert NameStyle.custom?(style)
    assert NameStyle.css_class(style) == "chat-name-gradient"

    assert NameStyle.css_style(style) =~
             "#99CCFF 0%, #99CCFF 12.5%, #6495ED 12.5%, #6495ED 25%"

    assert NameStyle.css_style(style) =~ "#FFFFFF 37.5%, #FFFFFF 62.5%"
    assert NameStyle.css_style(style) =~ "#FFC0CB 75%, #FFC0CB 87.5%, #FF69B4 87.5%"
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

  test "exposes one CSS contract for pattern and solid styles" do
    gradient = %{kind: :gradient, first: "#99CCFF", second: "#FF4040"}
    solid = %{kind: :solid, color: "#3EFF3E"}

    assert NameStyle.custom?(gradient)
    assert NameStyle.css_class(gradient) == "chat-name-gradient"
    assert NameStyle.css_style(gradient) =~ "linear-gradient"
    assert NameStyle.custom?(solid)
    assert NameStyle.css_class(solid) == nil
    assert NameStyle.css_style(solid) == "color: #3EFF3E"
    refute NameStyle.custom?(nil)
  end
end
