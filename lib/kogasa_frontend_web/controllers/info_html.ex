defmodule KogasaFrontendWeb.InfoHTML do
  use KogasaFrontendWeb, :html

  embed_templates "info_html/*"

  attr :item, :map, required: true
  attr :inert, :boolean, default: false
  attr :interactive, :boolean, default: false

  def weapon_tile(assigns) do
    ~H"""
    <a
      href={if @inert || @item.locked, do: nil, else: "#"}
      class={["on", @item.equipped && "is-equipped", @item.locked && "is-locked"]}
      title={@item.title}
      data-weapon-uid={@item.uid}
      data-weapon-name={@item.name}
      aria-pressed={@interactive && !@item.locked && to_string(@item.equipped)}
      aria-disabled={@item.locked && "true"}
    >
      <img
        class="btn-icon"
        src={@item.icon}
        alt=""
        width="96"
        height="96"
        loading="eager"
        decoding="sync"
        fetchpriority="high"
      />
      <span class="btn-label">{if @item.equipped, do: "Equipped", else: @item.name}</span>
      <span :if={@item.locked || @item.type_level != ""} class="type-lvl">
        {if @item.locked, do: "!shop Item", else: @item.type_level}
      </span>
      <div class="effects">
        <span :for={segment <- @item.effects} class={"seg " <> segment.cls}>{segment.text}</span>
      </div>
    </a>
    """
  end
end
