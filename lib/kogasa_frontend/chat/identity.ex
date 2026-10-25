defmodule KogasaFrontend.Chat.Identity do
  @moduledoc false

  alias KogasaFrontend.SteamSession

  def session_topic(token), do: "chat-session:" <> to_string(token)

  # Shared by the HTTP plug and LiveView: neither accepts identity from a form.
  def from_session(session, persona) do
    steamid = SteamSession.steamid(session)
    token = session["wt_chat_client_token"] || "anon"
    secret = Application.get_env(:kogasa_frontend, :chat_ip_secret, "changeme")

    %{
      steamid: steamid,
      steam_session_id: if(steamid, do: session["steam_session_id"]),
      personaname: if(steamid, do: nil, else: persona["display"]),
      persona: persona,
      iphash:
        :sha256
        |> :crypto.hash("#{secret}|#{token}")
        |> Base.encode16(case: :lower)
        |> String.slice(0, 8),
      rate_key: if(steamid, do: "steam:" <> steamid, else: token),
      browser_key: token,
      server_ip: Application.get_env(:kogasa_frontend, :chat_server_ip, "127.0.0.1"),
      server_port: Application.get_env(:kogasa_frontend, :chat_server_port, 443)
    }
  end

  def refresh(%{steamid: id} = actor) when is_binary(id) do
    if SteamSession.valid?(id, actor[:steam_session_id]), do: actor, else: anonymous(actor)
  end

  def refresh(actor), do: actor

  def anonymous(actor) do
    Map.merge(actor, %{
      steamid: nil,
      steam_session_id: nil,
      personaname: get_in(actor, [:persona, "display"]),
      rate_key: actor[:browser_key] || "anon"
    })
  end
end
