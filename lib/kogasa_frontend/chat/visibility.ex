defmodule KogasaFrontend.Chat.Visibility do
  @moduledoc false
  import Ecto.Query
  alias KogasaFrontend.Chat.MessageParts

  # An intentional authenticated web post is public even when passive game
  # activity is hidden. Never exempt player relays or system announcements.
  def visible?(row, excluded) do
    steamid = Map.get(row, :steamid) || Map.get(row, "steamid")
    hash = Map.get(row, :iphash) || Map.get(row, "iphash")

    (steamid not in excluded or MessageParts.authenticated_web?(row)) and
      hash not in Enum.map(excluded, &("player:" <> &1))
  end

  def public_filter(excluded) do
    relays = Enum.map(excluded, &("player:" <> &1))

    web =
      dynamic(
        [m],
        not is_nil(m.steamid) and m.steamid != "" and
          not is_nil(m.iphash) and m.iphash != "" and m.iphash != "system" and
          not like(m.iphash, "player:%") and
          not is_nil(m.server_ip) and m.server_ip != ""
      )

    dynamic(
      [m],
      (is_nil(m.steamid) or m.steamid not in ^excluded or ^web) and
        (is_nil(m.iphash) or m.iphash not in ^relays)
    )
  end
end
