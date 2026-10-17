defmodule KogasaFrontend.Chat.Sender do
  @moduledoc false
  alias KogasaFrontend.{PlayerIdentity, Chat.SourceName}

  def presentation(%{steamid: id}, profile, identity) when is_binary(id) and id != "" do
    name =
      PlayerIdentity.resolve_name(identity, profile && profile["personaname"], nil, id, :filters)

    name =
      String.replace(
        name,
        ~r/\x07[\da-fA-F]{6}|\x08[\da-fA-F]{8}|[\x00-\x1F\x7F]|\{[a-zA-Z]+\}/u,
        ""
      )

    name = if String.trim(name) == "", do: id, else: name
    style = identity[:name_style]

    %{
      display_name: name <> " | Web",
      relay_name: SourceName.render(name, style) <> " | Web",
      name_style: style
    }
  end

  def presentation(actor, _profile, _identity) do
    name = actor[:personaname] || "Web Player"
    %{display_name: name, relay_name: name, name_style: nil}
  end
end
