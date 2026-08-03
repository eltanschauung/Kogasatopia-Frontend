defmodule KogasaFrontendWeb.ChatText do
  @moduledoc false
  use Phoenix.Component

  alias KogasaFrontend.Chat.MoreColors
  alias KogasaFrontend.Chat.NameStyle

  @token_re ~r/(\{[a-zA-Z]+\})/

  attr :text, :string, required: true
  attr :class, :string, default: nil
  attr :title, :string, default: nil

  def colored(assigns) do
    assigns = assign(assigns, :segments, segments(assigns.text || ""))

    ~H"""
    <span class={@class} title={@title}>
      <%= for segment <- @segments do %>
        <span style={segment_style(segment.color)}>{segment.text}</span>
      <% end %>
    </span>
    """
  end

  attr :text, :string, required: true
  attr :name_style, :map, default: nil
  attr :class, :string, default: nil
  attr :title, :string, default: nil

  def chat_name(assigns) do
    ~H"""
    <%= if NameStyle.custom?(@name_style) do %>
      <span
        class={[@class, NameStyle.css_class(@name_style)]}
        style={NameStyle.css_style(@name_style)}
        title={@title}
      >
        {@text}
      </span>
    <% else %>
      <.colored text={@text} class={@class} title={@title} />
    <% end %>
    """
  end

  def segments(text) when is_binary(text) do
    text
    |> String.split(@token_re, include_captures: true, trim: false)
    |> Enum.reduce({nil, []}, fn part, {current_color, acc} ->
      case Regex.run(~r/^\{([a-zA-Z]+)\}$/, part) do
        [_, token] ->
          {normalize_color_token(token), acc}

        _ ->
          if part == "" do
            {current_color, acc}
          else
            {current_color, [%{text: part, color: current_color} | acc]}
          end
      end
    end)
    |> elem(1)
    |> Enum.reverse()
  end

  def segments(_), do: []

  defp normalize_color_token(token) do
    token = String.downcase(token)

    if token == "default", do: nil, else: MoreColors.css(token)
  end

  defp segment_style(nil), do: nil
  defp segment_style(color), do: "color: #{color}"
end
