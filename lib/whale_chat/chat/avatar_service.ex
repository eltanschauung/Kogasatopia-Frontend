defmodule WhaleChat.Chat.AvatarService do
  @moduledoc false

  alias WhaleChat.LegacyPaths

  def resolve(%{iphash: "system"}), do: server_avatar_url()

  def resolve(%{steamid: steamid, iphash: iphash, personaname: personaname, profile: profile}) do
    cond do
      is_binary(steamid) and steamid != "" ->
        profile_avatar(profile) || avatar_for_hash(iphash)

      true ->
        persona_avatar(personaname) || avatar_for_hash(iphash)
    end
  end

  def resolve(_), do: default_avatar_url()

  def default_avatar_url,
    do: Application.get_env(:whale_chat, :default_avatar_url, "/stats/assets/whaley-avatar.jpg")

  def secondary_avatar_url,
    do: Application.get_env(:whale_chat, :secondary_avatar_url, "/stats/assets/whaley-avatar-2.jpg")

  def server_avatar_url,
    do: Application.get_env(:whale_chat, :server_avatar_url, "/stats/assets/server-chat-avatar.jpg")

  def avatar_for_hash(nil), do: default_avatar_url()
  def avatar_for_hash(""), do: default_avatar_url()

  def avatar_for_hash(hash) when is_binary(hash) do
    last_char = hash |> String.downcase() |> String.slice(-1, 1)

    cond do
      last_char == "" -> default_avatar_url()
      Regex.match?(~r/^[0-9]$/, last_char) -> default_avatar_url()
      Regex.match?(~r/^[a-z]$/, last_char) -> secondary_avatar_url()
      true -> default_avatar_url()
    end
  end

  def persona_avatar(nil), do: nil
  def persona_avatar(""), do: nil

  def persona_avatar(persona_display) when is_binary(persona_display) do
    plain =
      persona_display
      |> String.replace(~r/\{[^}]+\}/, "")
      |> String.trim()
      |> String.replace(~r/^\[Web\]\s*/i, "")
      |> String.trim()

    if plain == "" do
      nil
    else
      filename = "#{plain}.jpg"
      path = Path.join(assets_dir(), filename)

      if File.regular?(path) do
        "/stats/assets/" <> URI.encode(filename)
      else
        nil
      end
    end
  end

  defp profile_avatar(%{"avatarfull" => avatar}) when is_binary(avatar) and avatar != "", do: avatar
  defp profile_avatar(%{avatarfull: avatar}) when is_binary(avatar) and avatar != "", do: avatar
  defp profile_avatar(_), do: nil

  defp assets_dir do
    LegacyPaths.stats_assets_dir()
  end
end
