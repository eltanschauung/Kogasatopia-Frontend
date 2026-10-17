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
end
