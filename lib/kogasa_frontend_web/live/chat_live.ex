defmodule KogasaFrontendWeb.ChatLive do
  use KogasaFrontendWeb, :live_view

  alias KogasaFrontend.Chat
  alias KogasaFrontend.Chat.Identity
  alias KogasaFrontend.Chat.{History, RateLimiter}
  alias KogasaFrontend.TimeDisplay
  alias KogasaFrontendWeb.Plugs.ChatIdentity
  @poll_ms 4_000

  @impl true
  def mount(_params, session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(KogasaFrontend.PubSub, Chat.topic())
      Process.send_after(self(), :poll_new_messages, @poll_ms)
    end

    persona = session["wt_chat_persona"] || Chat.ensure_session_persona(nil)

    identity =
      session
      |> Identity.from_session(persona)
      |> Map.merge(%{
        remote_ip: remote_ip(socket),
        source_subnet: source_subnet(socket, session)
      })

    if connected?(socket) && identity.steamid do
      Phoenix.PubSub.subscribe(
        KogasaFrontend.PubSub,
        Identity.session_topic(identity.browser_key)
      )
    end

    payload = Chat.list_messages(%{limit: 50})

    {:ok,
     socket
     |> assign(:page_title, "Live Chat")
     |> assign(:messages, payload.messages || [])
     |> assign(:latest_id, payload.latest_id || payload.newest_id)
     |> assign(:oldest_id, payload.oldest_id)
     |> assign(:has_more_older, payload.has_more_older)
     |> assign(:history_mode, false)
     |> assign(:poll_after_id, payload.latest_id || payload.newest_id)
     |> assign(:status, nil)
     |> assign(:message_input, "")
     |> assign(:identity, identity)}
  end

  @impl true
  def handle_event("send", %{"message" => message}, socket) do
    case Chat.submit_message(socket.assigns.identity, message) do
      {:ok, :sent} ->
        {:noreply, assign(socket, message_input: "", status: nil)}

      {:ok, {:persona_updated, persona}} ->
        identity = %{socket.assigns.identity | personaname: persona["display"], persona: persona}

        {:noreply,
         socket
         |> assign(:identity, identity)
         |> assign(:message_input, "")
         |> assign(:status, "Persona updated")}

      {:ok, {:persona_not_found, options}} ->
        names =
          options
          |> Enum.map(&Map.get(&1, "name"))
          |> Enum.filter(&is_binary/1)
          |> Enum.join(", ")

        status =
          if names == "", do: "Persona not found", else: "Persona not found — available: #{names}"

        {:noreply, assign(socket, :status, status)}

      {:error, :hourly_rate_limited} ->
        {:noreply, assign(socket, :status, Chat.hourly_limit_message(socket.assigns.identity))}

      {:error, :rate_limited} ->
        {:noreply, assign(socket, :status, "Rate limited (wait 5s)")}

      {:error, :duplicate_rate_limited} ->
        {:noreply, assign(socket, :status, "Repeated message limit reached (3 per 5 minutes)")}

      {:error, :spam_limited} ->
        {:noreply, assign(socket, :status, "Message blocked by antispam")}

      {:error, :ip_banned} ->
        {:noreply, assign(socket, :status, "Your network is banned from webchat for one week")}

      {:error, :invalid} ->
        {:noreply, assign(socket, :status, "Invalid message")}

      {:error, :authentication_expired} ->
        {:noreply,
         socket
         |> assign(:identity, Identity.anonymous(socket.assigns.identity))
         |> assign(:status, "Steam session expired. Please sign in again.")}

      {:error, _} ->
        {:noreply, assign(socket, :status, "Failed to send message")}
    end
  end

  @impl true
  def handle_event("change", %{"message" => message}, socket) do
    if Chat.valid_input?(message),
      do: {:noreply, assign(socket, :message_input, message)},
      else: {:noreply, assign(socket, :status, "Invalid message")}
  end

  @impl true
  def handle_event("load_older", _params, socket) do
    if socket.assigns.has_more_older && socket.assigns.oldest_id && history_allowed?(socket) do
      payload = Chat.list_messages(%{before: socket.assigns.oldest_id, limit: 50})
      older = payload.messages || []
      merged = History.prepend(socket.assigns.messages, older)
      prepended = older != []

      {:reply,
       %{
         prepended: prepended,
         has_more_older: payload.has_more_older,
         oldest_id: payload.oldest_id
       },
       socket
       |> assign(:messages, merged)
       |> assign(:history_mode, socket.assigns.history_mode or prepended)
       |> assign(:oldest_id, payload.oldest_id || socket.assigns.oldest_id)
       |> assign(:has_more_older, payload.has_more_older)}
    else
      {:reply,
       %{
         prepended: false,
         has_more_older: socket.assigns.has_more_older,
         oldest_id: socket.assigns.oldest_id
       }, socket}
    end
  end

  def handle_event("load_latest", _params, socket) do
    if history_allowed?(socket) do
      payload = Chat.list_messages(%{limit: 50})

      {:reply, %{live: true},
       socket
       |> assign(:messages, payload.messages || [])
       |> assign(:oldest_id, payload.oldest_id)
       |> assign(:latest_id, payload.latest_id)
       |> assign(:poll_after_id, payload.latest_id)
       |> assign(:history_mode, false)
       |> assign(:has_more_older, payload.has_more_older)
       |> assign(:status, nil)}
    else
      {:reply, %{live: false},
       assign(socket, :status, "Please wait before loading more history.")}
    end
  end

  def handle_event(_event, _params, socket),
    do: {:noreply, assign(socket, :status, "Invalid request")}

  @impl true
  def handle_info(:steam_logout, socket) do
    identity = socket.assigns.identity

    identity = Identity.anonymous(identity)

    {:noreply, assign(socket, :identity, identity)}
  end

  def handle_info({:new_message, msg}, socket) do
    if socket.assigns.history_mode do
      {:noreply, socket}
    else
      {:noreply, append_messages(socket, [msg])}
    end
  end

  @impl true
  def handle_info(:poll_new_messages, socket) do
    socket = update(socket, :identity, &Identity.refresh/1)

    socket =
      if socket.assigns.history_mode do
        socket
      else
        payload =
          case socket.assigns[:poll_after_id] do
            id when is_integer(id) and id > 0 -> Chat.list_messages(%{after: id, limit: 100})
            _ -> Chat.list_messages(%{limit: 50})
          end

        socket
        |> append_messages(payload[:messages] || [])
        |> assign(:poll_after_id, payload[:latest_id] || socket.assigns[:poll_after_id])
      end

    Process.send_after(self(), :poll_new_messages, @poll_ms)
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} wide={true}>
      <div id="chat-container">
        <.section_nav
          active={:chat}
          online_count_id="chat-nav-online-count-top"
        />

        <div class="wt-topbar">
          <div>
            <h1>WhaleChat</h1>
            <p id="nav-chat-label">Last msg. --</p>
          </div>
          <span
            id="nav-online-count"
            class="wt-topbar-count"
            data-mirror-target="chat-nav-online-count-top"
          >
            -- / --
          </span>
        </div>

        <div id="chat-panel" class="players-list">
          <button :if={@history_mode} id="chat-return-live" type="button" phx-click="load_latest">
            Viewing history — Return to live chat
          </button>
          <div
            id="chat-messages"
            phx-hook="ChatViewport"
            data-history-mode={if(@history_mode, do: "1", else: "0")}
          >
            <%= if @messages == [] do %>
              <p class="chat-empty">No messages yet.</p>
            <% else %>
              <%= for msg <- @messages do %>
                <div
                  id={"msg-#{msg.id}"}
                  data-chat-row
                  data-chat-id={msg.id}
                  data-chat-alert={if(msg.alert, do: "1", else: "0")}
                  class="chat-row"
                >
                  <img src={msg.avatar} alt="" class="chat-avatar" />
                  <div class="chat-content">
                    <div class="chat-header">
                      <div class="chat-identity">
                        <.colored
                          :if={is_binary(msg.clan_tag) and msg.clan_tag != ""}
                          text={msg.clan_tag}
                          class="chat-clan-tag"
                        />
                        <.chat_name
                          text={msg.name}
                          name_style={msg.name_style}
                          class="chat-name"
                        />
                      </div>
                      <span
                        class="chat-timestamp"
                        data-local-time={msg.created_at}
                        data-time-format="time"
                      >
                        {format_time(msg.created_at)}
                      </span>
                    </div>
                    <div class="chat-text">
                      <.colored text={msg.message} />
                    </div>
                  </div>
                </div>
              <% end %>
            <% end %>
          </div>

          <div class="chat-nav-stack" aria-label="Chat navigation controls">
            <button
              id="chat-btn-lock"
              type="button"
              aria-pressed="true"
              title="Lock chat to bottom"
              class="navarrow navarrow-lock"
            >
              <img src="/stats/assets/keine_lock.png" alt="Lock chat to bottom" />
            </button>
            <button
              id="chat-btn-top"
              type="button"
              title="Scroll to top"
              class="navarrow navarrow-top"
            >
              <img src="/stats/assets/reisen_up.png" alt="Scroll to top" />
            </button>
            <button
              id="chat-btn-bottom"
              type="button"
              title="Scroll to bottom"
              class="navarrow navarrow-bottom"
            >
              <img src="/stats/assets/tewi_down.png" alt="Scroll to bottom" />
            </button>
          </div>
        </div>

        <form
          id="chat-form"
          phx-submit="send"
          phx-change="change"
          class="chat-form"
          autocomplete="off"
        >
          <textarea
            id="chat-input"
            name="message"
            phx-hook="ChatComposer"
            rows="2"
            maxlength="180"
            data-dynamic-placeholder="Type to {count} players | All messages are deleted after 24hrs"
            placeholder="Type to 0 players | All messages are deleted after 24hrs"
          ><%= @message_input %></textarea>
          <button id="chat-send" type="submit">Send</button>
        </form>

        <div id="chat-status" class={["chat-status", @status && "chat-status-error"]}>{@status}</div>
      </div>
    </Layouts.app>
    """
  end

  defp format_time(nil), do: ""

  defp format_time(seconds) when is_integer(seconds) do
    case TimeDisplay.format_server_time(seconds) do
      "n/a" -> ""
      formatted -> formatted
    end
  end

  defp format_time(_), do: ""

  defp history_allowed?(socket) do
    actor = socket.assigns.identity
    keys = ["chat-history:browser:" <> to_string(actor[:browser_key] || "unknown")]

    keys =
      if actor[:remote_ip] not in [nil, ""],
        do: ["chat-history:ip:" <> actor.remote_ip | keys],
        else: keys

    RateLimiter.allow_count?(keys, 30, 60)
  end

  defp append_messages(socket, incoming) do
    combined = socket.assigns.messages ++ incoming
    window = History.append(socket.assigns.messages, incoming)
    ids = Enum.map(window, & &1.id)

    socket
    |> assign(:messages, window)
    |> assign(:latest_id, List.last(ids) || socket.assigns.latest_id)
    |> assign(:oldest_id, List.first(ids) || socket.assigns.oldest_id)
    |> assign(
      :has_more_older,
      socket.assigns.has_more_older or length(combined) > History.limit()
    )
  end

  defp source_subnet(socket, session) do
    if connected?(socket) do
      case get_connect_info(socket, :peer_data) do
        %{address: address} -> ChatIdentity.source_subnet_for_ip(address)
        _ -> session["wt_chat_source_subnet"]
      end
    else
      session["wt_chat_source_subnet"]
    end
  end

  defp remote_ip(socket) do
    if connected?(socket) do
      case get_connect_info(socket, :peer_data) do
        %{address: address} -> ChatIdentity.remote_ip_string(address)
        _ -> ""
      end
    else
      ""
    end
  end
end
