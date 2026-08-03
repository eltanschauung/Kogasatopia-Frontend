defmodule KogasaFrontend.Chat.MessagePartsTest do
  use ExUnit.Case, async: true

  alias KogasaFrontend.Chat.MessageParts

  test "moves a colored clan tag out of a game message" do
    message =
      "{default}[{gold}{pink}TEWI{default}] {grey}Inaba Tewi{default}{default} : hello"

    assert MessageParts.split(message, game_source()) == {
             "[{gold}{pink}TEWI{default}]",
             "hello"
           }
  end

  test "removes the rendered client name when no clan tag exists" do
    message = "{default}{frozen}LunarWaves{default}{default} : gibs"

    assert MessageParts.split(message, game_source()) == {nil, "gibs"}
  end

  test "preserves delimiters in the message body" do
    message = "{default}\x07FF4040Player\x01{default} : first : second"

    assert MessageParts.split(message, game_source()) == {nil, "first : second"}
  end

  test "does not parse web messages" do
    message = "this is not a rendered name : keep all of it"

    assert MessageParts.split(message, %{
             steamid: "76561198000000000",
             iphash: "web-session",
             server_ip: "127.0.0.1"
           }) == {nil, message}
  end

  test "does not parse system messages" do
    message = "{gold}[Server]{default}: map changed"
    assert MessageParts.split(message, %{steamid: nil, iphash: "system"}) == {nil, message}
  end

  defp game_source do
    %{steamid: "76561198000000000", iphash: nil, server_ip: nil}
  end
end
