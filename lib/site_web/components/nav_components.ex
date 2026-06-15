defmodule WhaleChatWeb.NavComponents do
  @moduledoc false
  use Phoenix.Component

  attr :active, :atom,
    required: true,
    values: [:blog, :stats, :online, :logs, :chat, :mapsdb]

  attr :online_count_id, :string, default: "nav-online-count"
  attr :online_count_class, :string, default: "chat-nav-pill-count"
  attr :chat_label_id, :string, default: nil
  attr :chat_label_class, :string, default: "chat-nav-pill-count"

  def section_nav(assigns) do
    ~H"""
    <div class="chat-nav-row chat-nav-row-top">
      <.nav_item active={@active == :blog} href="/" label="Blog" kind="home" class="site-nav-blog" />
      <.nav_item active={@active == :stats} href="/stats" label="Stats" kind="home" class="site-nav-navy" />
      <.nav_item active={@active == :mapsdb} href="/mapsdb" label="MapsDB" kind="pill" class="site-nav-navy" />
      <.nav_item
        active={@active == :online}
        href="/online"
        label="Online Now"
        kind="pill"
        class="site-nav-gold"
        online_count_id={@online_count_id}
        online_count_class={@online_count_class}
      />
      <.nav_item
        active={@active == :chat}
        href="/chat"
        label="Chat"
        kind="pill"
        class="site-nav-gold"
        chat_label_id={@chat_label_id}
        chat_label_class={@chat_label_class}
      />
      <.nav_item active={@active == :logs} href="/logs" label="Match Logs" kind="pill" class="site-nav-gold" />
    </div>
    """
  end

  attr :active, :boolean, default: false
  attr :href, :string, required: true
  attr :label, :string, required: true
  attr :kind, :string, default: "pill", values: ["pill", "home"]
  attr :class, :string, default: nil
  attr :online_count_id, :string, default: nil
  attr :online_count_class, :string, default: "chat-nav-pill-count"
  attr :chat_label_id, :string, default: nil
  attr :chat_label_class, :string, default: "chat-nav-pill-count"

  defp nav_item(%{kind: "home"} = assigns) do
    if assigns.active do
      ~H"""
      <span class={["chat-home-btn", @class]} aria-current="page">{@label}</span>
      """
    else
      ~H"""
      <a href={@href} class={["chat-home-btn", @class]}>{@label}</a>
      """
    end
  end

  defp nav_item(assigns) do
    if assigns.active do
      ~H"""
      <span class={["chat-nav-pill", @class]} aria-current="page">
        {@label}
        <span :if={@online_count_id} id={@online_count_id} class={@online_count_class}>
          -- / --
        </span>
        <span :if={@chat_label_id} id={@chat_label_id} class={@chat_label_class}>
          Last msg. --
        </span>
      </span>
      """
    else
      ~H"""
      <a href={@href} class={["chat-nav-pill", @class]}>
        {@label}
        <span :if={@online_count_id} id={@online_count_id} class={@online_count_class}>
          -- / --
        </span>
        <span :if={@chat_label_id} id={@chat_label_id} class={@chat_label_class}>
          Last msg. --
        </span>
      </a>
      """
    end
  end
end
