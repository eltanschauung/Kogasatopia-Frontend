defmodule KogasaFrontend.Chat.MessageParts do
  @moduledoc false

  @clan_tag_re ~r/\[[^\]\r\n]*\]/u

  def split(message, source) when is_binary(message) and is_map(source) do
    cond do
      authenticated_web?(source) -> {"{gold}[Web]{default}", message}
      game_chat?(source) -> split_game_message(message)
      true -> {nil, message}
    end
  end

  def split(message, _source) when is_binary(message), do: {nil, message}
  def split(_message, _source), do: {nil, ""}

  def authenticated_web?(source) do
    hash = value(source, :iphash)

    present?(value(source, :steamid)) and present?(hash) and hash != "system" and
      not String.starts_with?(hash, "player:") and present?(value(source, :server_ip))
  end

  defp game_chat?(source) do
    present?(value(source, :steamid)) and
      blank?(value(source, :iphash)) and
      blank?(value(source, :server_ip))
  end

  defp split_game_message(message) do
    case String.split(message, " : ", parts: 2) do
      [prefix, body] -> {extract_clan_tag(prefix), body}
      _ -> {nil, message}
    end
  end

  defp extract_clan_tag(prefix) do
    case Regex.run(@clan_tag_re, prefix) do
      [tag] -> tag
      _ -> nil
    end
  end

  defp value(map, key), do: Map.get(map, key) || Map.get(map, Atom.to_string(key))
  defp present?(value), do: is_binary(value) and String.trim(value) != ""
  defp blank?(value), do: not present?(value)
end
