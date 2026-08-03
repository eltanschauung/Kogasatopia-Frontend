defmodule KogasaFrontend.PlayerPresentation do
  @moduledoc false

  alias KogasaFrontend.Chat.NameStyle
  alias KogasaFrontend.CountryNames

  @flag_base_url "https://bantculture.com/static/flags/"

  def name_attributes(name_style, is_admin, base_classes \\ []) do
    custom_style? = NameStyle.custom?(name_style)
    style_class = NameStyle.css_class(name_style)

    classes =
      base_classes
      |> List.wrap()
      |> Enum.reject(&is_nil/1)
      |> maybe_push(is_binary(style_class), style_class)
      |> maybe_push(is_admin && !custom_style?, "admin-name")
      |> Enum.join(" ")

    %{
      classes: classes,
      style: NameStyle.css_style(name_style),
      title: if(is_admin, do: "Admin", else: "Player")
    }
  end

  def steam_profile_url(nil), do: nil

  def steam_profile_url(%{profileurl: url}) when is_binary(url) and url != "", do: url
  def steam_profile_url(%{"profileurl" => url}) when is_binary(url) and url != "", do: url

  def steam_profile_url(map) when is_map(map) do
    steamid = map[:steamid] || map["steamid"] || map[:steamid64] || map["steamid64"]
    steam_profile_url(steamid)
  end

  def steam_profile_url(steamid) when is_binary(steamid) do
    steamid = String.trim(steamid)

    if Regex.match?(~r/^7656\d+$/, steamid),
      do: "https://steamcommunity.com/profiles/" <> steamid,
      else: nil
  end

  def steam_profile_url(_), do: nil

  def country_flag(code, fallback_name \\ "") do
    case CountryNames.normalize_code(code) do
      "" ->
        nil

      normalized ->
        name =
          case to_string(fallback_name || "") |> String.trim() do
            "" -> CountryNames.display_name(normalized)
            value -> value
          end

        %{
          code: normalized,
          name: name,
          url: @flag_base_url <> URI.encode(normalized) <> ".png"
        }
    end
  end

  defp maybe_push(list, true, value), do: list ++ [value]
  defp maybe_push(list, _, _), do: list
end
