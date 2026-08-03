defmodule KogasaFrontendWeb.ChatText do
  @moduledoc false
  use Phoenix.Component

  alias KogasaFrontend.Chat.MoreColors

  @token_re ~r/(\{[a-zA-Z]+\})/

  attr :text, :string, required: true
  attr :class, :string, default: nil

  def colored(assigns) do
    assigns = assign(assigns, :segments, segments(assigns.text || ""))

    ~H"""
    <span class={@class}>
      <%= for segment <- @segments do %>
        <span style={segment_style(segment.color)}>{segment.text}</span>
      <% end %>
    </span>
    """
  end

  attr :text, :string, required: true
  attr :name_style, :map, default: nil
  attr :class, :string, default: nil

  def chat_name(assigns) do
    ~H"""
    <%= case @name_style do %>
      <% %{kind: :gradient, first: first, second: second} -> %>
        <span
          class={[@class, "chat-name-gradient"]}
          style={"--chat-name-gradient: linear-gradient(90deg, #{first}, #{second})"}
        >
          {@text}
        </span>
      <% %{kind: :america} -> %>
        <span
          class={[@class, "chat-name-gradient"]}
          style="--chat-name-gradient: linear-gradient(90deg, #FF4040 0%, #FF4040 33.333%, #FFFFFF 33.333%, #FFFFFF 66.666%, #1E90FF 66.666%, #1E90FF 100%)"
        >
          {@text}
        </span>
      <% %{kind: :solid, color: color} -> %>
        <span class={@class} style={"color: #{color}"}>{@text}</span>
      <% _ -> %>
        <.colored text={@text} class={@class} />
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
