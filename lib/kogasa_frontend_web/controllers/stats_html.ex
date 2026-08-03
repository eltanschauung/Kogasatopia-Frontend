defmodule KogasaFrontendWeb.StatsHTML do
  use KogasaFrontendWeb, :html

  alias KogasaFrontend.DisplayFormat
  alias KogasaFrontend.PlayerPresentation

  embed_templates "stats_html/*"

  def number_format(value), do: DisplayFormat.integer(value)
  def format_decimal(value, digits \\ 1), do: DisplayFormat.decimal(value, digits)

  def summary_week_trend_class(summary) do
    {_, trend} = normalized_week_change(summary)

    if trend in ["up", "down", "flat"],
      do: "stat-card-trend stat-card-trend--#{trend}",
      else: "stat-card-trend stat-card-trend--flat"
  end

  def summary_week_change_label(summary) do
    case elem(normalized_week_change(summary), 0) do
      nil ->
        "—"

      value when is_number(value) ->
        sign = if value >= 0, do: "+", else: ""
        sign <> :erlang.float_to_binary(value / 1, decimals: 1) <> "%"

      _ ->
        "—"
    end
  end

  def summary_week_tooltip(summary) do
    label = summary_week_change_label(summary)
    "Change vs prior 7 days: " <> if(label == "—", do: "not enough data", else: label)
  end

  def avatar_or_default(nil, default), do: default

  def avatar_or_default(map, default) when is_map(map),
    do: map[:avatar] || map["avatar"] || default

  def avatar_or_default(_, default), do: default

  def steam_profile_url(value), do: PlayerPresentation.steam_profile_url(value)

  def display_name(nil), do: "Unknown"

  def display_name(map) when is_map(map),
    do: map[:personaname] || map["personaname"] || map[:steamid] || map["steamid"] || "Unknown"

  def display_name(v), do: to_string(v)

  def player_name_style(player), do: get_key(player, :name_style, nil)

  def player_name_class(player, base_class) do
    player
    |> player_name_attributes(base_class)
    |> Map.fetch!(:classes)
  end

  def player_name_title(player), do: player_name_attributes(player, nil).title

  def map_get(summary, key, default \\ nil), do: get_key(summary, key, default)

  defp get_key(map, key, default) when is_map(map) do
    Map.get(map, key, Map.get(map, Atom.to_string(key), default))
  end

  defp get_key(_, _key, default), do: default

  defp player_name_attributes(player, base_class) do
    PlayerPresentation.name_attributes(
      player_name_style(player),
      get_key(player, :is_admin, false),
      [base_class]
    )
  end

  # Match PHP wt_build_summary_context() behavior: clamp negative weekly change to 0.0 and mark as "up".
  defp normalized_week_change(summary) do
    raw = get_key(summary, :players_week_change_percent, nil)
    trend = get_key(summary, :players_week_trend, "flat") |> to_string()
    trend = if trend in ["up", "down", "flat"], do: trend, else: "flat"

    cond do
      is_number(raw) and raw < 0.0 -> {0.0, "up"}
      is_number(raw) -> {raw / 1, trend}
      true -> {nil, trend}
    end
  end
end
