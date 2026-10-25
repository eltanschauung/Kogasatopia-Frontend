defmodule KogasaFrontendWeb.ChatInputSecurityTest do
  use ExUnit.Case, async: true
  alias KogasaFrontend.Chat
  alias KogasaFrontendWeb.ChatLive

  test "malformed and oversized input never reaches processing or LiveView assigns" do
    socket = %Phoenix.LiveView.Socket{
      assigns: %{identity: %{}, message_input: "kept", __changed__: %{}}
    }

    for value <- [%{}, [], nil, 42, <<255>>, String.duplicate("a", 16_385)] do
      assert {:error, :invalid} = Chat.submit_message(%{}, value)
      assert {:noreply, result} = ChatLive.handle_event("send", %{"message" => value}, socket)
      assert result.assigns.status == "Invalid message"
      assert {:noreply, result} = ChatLive.handle_event("change", %{"message" => value}, socket)
      assert result.assigns.message_input == "kept"
    end

    assert {:noreply, _} = ChatLive.handle_event("send", %{}, socket)
    assert Chat.valid_input?(String.duplicate("人", 180))
  end
end
