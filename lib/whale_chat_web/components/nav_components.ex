defmodule WhaleChatWeb.NavComponents do
  @moduledoc false
  use Phoenix.Component

  attr :active, :atom,
    required: true,
    values: [:blog, :stats, :online, :logs, :chat, :mapsdb]

  attr :online_count_id, :string, default: "nav-online-count"
  attr :online_count_class, :string, default: "wt-nav-count"
  attr :chat_label_id, :string, default: nil
  attr :chat_label_class, :string, default: "wt-nav-count"

  def section_nav(assigns) do
    ~H"""
    <nav class="wt-nav" aria-label="WhaleTracker">
      <.nav_item active={@active == :blog} href="/" label="Blog" />
      <.nav_item active={@active == :stats} href="/stats" label="Stats" />
      <.nav_item active={@active == :mapsdb} href="/mapsdb" label="MapsDB" />
      <.nav_item
        active={@active == :online}
        href="/online"
        label="Online Now"
        online_count_id={@online_count_id}
        online_count_class={@online_count_class}
      />
      <.nav_item
        active={@active == :chat}
        href="/chat"
        label="Chat"
        chat_label_id={@chat_label_id}
        chat_label_class={@chat_label_class}
      />
      <.nav_item active={@active == :logs} href="/logs" label="Match Logs" />
    </nav>
    """
  end

  attr :active, :boolean, default: false
  attr :href, :string, required: true
  attr :label, :string, required: true
  attr :class, :string, default: nil
  attr :online_count_id, :string, default: nil
  attr :online_count_class, :string, default: "wt-nav-count"
  attr :chat_label_id, :string, default: nil
  attr :chat_label_class, :string, default: "wt-nav-count"

  defp nav_item(assigns) do
    if assigns.active do
      ~H"""
      <span class={["wt-nav-link", "is-active", @class]} aria-current="page">
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
      <a href={@href} class={["wt-nav-link", @class]}>
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
