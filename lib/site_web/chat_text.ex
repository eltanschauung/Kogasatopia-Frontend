defmodule WhaleChatWeb.ChatText do
  @moduledoc false
  use Phoenix.Component

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

    cond do
      token == "default" -> nil
      Regex.match?(~r/^[a-z]+$/, token) -> token
      true -> nil
    end
  end

  defp segment_style(nil), do: nil
  defp segment_style(color), do: "color: #{css_color(color)}"

  defp css_color("cornflowerblue"), do: "#6495ED"
  defp css_color("blue"), do: "#80B5FF"
  defp css_color("gold"), do: "#FFD700"
  defp css_color("green"), do: "#00FF90"
  defp css_color("red"), do: "#FF4040"
  defp css_color("gray"), do: "#CCCCCC"
  defp css_color("yellow"), do: "#FFEA00"
  defp css_color("white"), do: "#FFFFFF"
  defp css_color("black"), do: "#000000"
  defp css_color(color), do: color
end
