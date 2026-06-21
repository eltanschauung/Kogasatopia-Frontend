defmodule KogasaFrontendWeb.NavComponents do
  @moduledoc false
  use Phoenix.Component

  attr :active, :atom,
    required: true,
    values: [:blog, :stats, :online, :logs, :chat, :maps, :weapons]

  attr :class, :any, default: nil
  attr :online_count_id, :any, default: "nav-online-count"
  attr :online_count_class, :string, default: "tab-button-count"
  attr :chat_label_id, :any, default: nil
  attr :chat_label_class, :string, default: "tab-button-count"
  slot :inner_block

  def section_nav(assigns) do
    ~H"""
    <div class={["stats-home-row", @class]}>
      <div class="tab-controls">
        <.nav_item active={@active == :blog} href="/" label="Blog" class="wt-tab--orange" />
        <.nav_item
          active={@active == :stats}
          href="/stats"
          label="Stats"
          class="wt-tab--navy"
        />
        <.nav_item
          active={@active == :maps}
          href="/maps"
          label="Maps"
          class="wt-tab--navy"
        />
        <.nav_item
          active={@active == :weapons}
          href="/weapons"
          label="Weapons"
          class="wt-tab--navy"
        />
        <.nav_item
          active={@active == :online}
          href="/online"
          label="Online Now"
          mobile_label="Online"
          class="wt-tab--gold"
          online_count_id={@online_count_id}
          online_count_class={@online_count_class}
        />
        <.nav_item
          active={@active == :chat}
          href="/chat"
          label="Chat"
          class="wt-tab--gold"
          chat_label_id={@chat_label_id}
          chat_label_class={@chat_label_class}
        />
        <.nav_item
          active={@active == :logs}
          href="/logs"
          label="Match Logs"
          mobile_label="Logs"
          class="wt-tab--gold"
        />
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  attr :active, :boolean, default: false
  attr :href, :string, required: true
  attr :label, :string, required: true
  attr :mobile_label, :string, default: nil
  attr :class, :string, default: nil
  attr :online_count_id, :any, default: nil
  attr :online_count_class, :string, default: "tab-button-count"
  attr :chat_label_id, :any, default: nil
  attr :chat_label_class, :string, default: "tab-button-count"

  defp nav_item(assigns) do
    assigns = assign(assigns, :mobile_label, assigns.mobile_label || assigns.label)

    if assigns.active do
      ~H"""
      <span class={["tab-button", @class]} aria-current="page">
        <span class="tab-button-label tab-button-label--desktop">{@label}</span>
        <span class="tab-button-label tab-button-label--mobile">{@mobile_label}</span>
        <span
          :if={@online_count_id}
          id={@online_count_id}
          class={@online_count_class}
          aria-live="polite"
        >
          -- / --
        </span>
        <span :if={@chat_label_id} id={@chat_label_id} class={@chat_label_class} aria-live="polite">
          Last msg. --
        </span>
      </span>
      """
    else
      ~H"""
      <a href={@href} class={["tab-button", @class]}>
        <span class="tab-button-label tab-button-label--desktop">{@label}</span>
        <span class="tab-button-label tab-button-label--mobile">{@mobile_label}</span>
        <span
          :if={@online_count_id}
          id={@online_count_id}
          class={@online_count_class}
          aria-live="polite"
        >
          -- / --
        </span>
        <span :if={@chat_label_id} id={@chat_label_id} class={@chat_label_class} aria-live="polite">
          Last msg. --
        </span>
      </a>
      """
    end
  end
end
