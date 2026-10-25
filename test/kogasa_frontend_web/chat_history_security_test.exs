defmodule KogasaFrontendWeb.ChatHistorySecurityTest do
  use KogasaFrontend.DataCase, async: false
  @moduletag :database
  alias KogasaFrontend.Chat.Message
  alias KogasaFrontendWeb.ChatLive

  defp mount do
    session = %{
      "wt_chat_client_token" => "history-#{System.unique_integer([:positive])}",
      "wt_chat_persona" => %{"display" => "Guest"}
    }

    {:ok, socket} =
      ChatLive.mount(%{}, session, %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}}})

    socket
  end

  test "history is bounded but remains navigable and can return to the live tail" do
    now = System.system_time(:second)

    Repo.insert_all(
      Message,
      Enum.map(1..650, &%{created_at: now, message: "history #{&1}", alert: true})
    )

    socket = mount()
    initial_id = socket.assigns.latest_id

    socket =
      Enum.reduce(1..12, socket, fn _, socket ->
        assert {:reply, %{prepended: true}, result} =
                 ChatLive.handle_event("load_older", %{}, socket)

        assert length(result.assigns.messages) <= 500
        result
      end)

    assert socket.assigns.history_mode
    refute socket.assigns.has_more_older
    assert socket.assigns.oldest_id < initial_id
    messages = socket.assigns.messages
    fresh = Repo.insert!(%Message{created_at: now, message: "fresh", alert: true})
    assert {:noreply, socket} = ChatLive.handle_info({:new_message, %{id: fresh.id}}, socket)
    assert socket.assigns.messages == messages
    assert {:noreply, socket} = ChatLive.handle_info(:poll_new_messages, socket)
    assert socket.assigns.messages == messages
    assert {:reply, %{live: true}, socket} = ChatLive.handle_event("load_latest", %{}, socket)
    refute socket.assigns.history_mode
    assert length(socket.assigns.messages) == 50
    assert socket.assigns.latest_id == fresh.id
  end

  test "out-of-order PubSub cannot skip database rows between polling cursors" do
    socket = mount()
    now = System.system_time(:second)

    records =
      for i <- 1..3, do: Repo.insert!(%Message{created_at: now, message: "new #{i}", alert: true})

    newest = List.last(records)
    assert {:noreply, socket} = ChatLive.handle_info({:new_message, %{id: newest.id}}, socket)
    assert {:noreply, socket} = ChatLive.handle_info(:poll_new_messages, socket)
    assert Enum.map(socket.assigns.messages, & &1.id) == Enum.map(records, & &1.id)
    assert socket.assigns.poll_after_id == newest.id
  end

  test "history fetches are paced and do not repeatedly query after quota is spent" do
    socket = mount()
    key = "chat-history:browser:" <> socket.assigns.identity.browser_key
    for _ <- 1..30, do: KogasaFrontend.Chat.RateLimiter.allow_count?(key, 30, 60)
    assert {:reply, %{live: false}, result} = ChatLive.handle_event("load_latest", %{}, socket)
    assert result.assigns.messages == socket.assigns.messages
  end

  test "duplicate arrivals cannot invent an older-history indicator" do
    socket = mount()
    messages = Enum.map(1..500, &%{id: &1})
    socket = Phoenix.Component.assign(socket, messages: messages, has_more_older: false)
    assert {:noreply, result} = ChatLive.handle_info({:new_message, %{id: 500}}, socket)
    assert result.assigns.messages == messages
    refute result.assigns.has_more_older
  end
end
