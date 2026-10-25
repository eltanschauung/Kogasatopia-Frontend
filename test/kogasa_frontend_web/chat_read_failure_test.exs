defmodule KogasaFrontendWeb.ChatReadFailureTest do
  # No sandbox checkout: querying the isolated Repo intentionally fails ownership.
  # This exercises the outage path without stopping a shared DB or service.
  use ExUnit.Case, async: false
  @moduletag :database

  alias KogasaFrontend.Chat
  alias KogasaFrontendWeb.ChatLive

  test "failed history reads do not pretend to be an empty successful history" do
    assert %{ok: false, messages: []} = Chat.list_messages()

    session = %{
      "wt_chat_client_token" => "failed-read-#{System.unique_integer([:positive])}",
      "wt_chat_persona" => %{"display" => "Guest"}
    }

    {:ok, socket} =
      ChatLive.mount(%{}, session, %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}}})

    socket =
      Phoenix.Component.assign(socket,
        messages: [%{id: 7}],
        oldest_id: 7,
        latest_id: 7,
        poll_after_id: 7,
        has_more_older: true,
        history_mode: true
      )

    assert {:reply, %{live: false}, result} = ChatLive.handle_event("load_latest", %{}, socket)
    assert result.assigns.messages == [%{id: 7}]
    assert result.assigns.history_mode
    assert result.assigns.poll_after_id == 7
    assert result.assigns.status =~ "temporarily unavailable"

    assert {:reply, %{prepended: false, has_more_older: true, oldest_id: 7}, result} =
             ChatLive.handle_event("load_older", %{}, socket)

    assert result.assigns.messages == [%{id: 7}]
    assert result.assigns.has_more_older
    assert result.assigns.oldest_id == 7
  end
end
