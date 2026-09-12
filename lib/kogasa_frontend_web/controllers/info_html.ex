defmodule KogasaFrontendWeb.InfoHTML do
  use KogasaFrontendWeb, :html

  embed_templates "info_html/*"

  attr :item, :map, required: true
  attr :inert, :boolean, default: false

  def weapon_tile(assigns) do
    ~H"""
    <a href={if @inert, do: nil, else: "#"} class="on" title={@item.title}>
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
      <span class="btn-label">{@item.name}</span>
      <span :if={@item.type_level != ""} class="type-lvl">{@item.type_level}</span>
      <div class="effects">
        <span :for={segment <- @item.effects} class={"seg " <> segment.cls}>{segment.text}</span>
      </div>
    </a>
    """
  end
end
