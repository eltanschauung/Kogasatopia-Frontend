defmodule WhaleChatWeb.Plugs.ChatIdentity do
  @moduledoc false
  import Plug.Conn
  alias WhaleChat.Chat

  def init(opts), do: opts

  def call(conn, _opts) do
    client_token =
      get_session(conn, "wt_chat_client_token") ||
        :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)

    persona = Chat.ensure_session_persona(get_session(conn, "wt_chat_persona"))

    conn =
      conn
      |> put_session("wt_chat_client_token", client_token)
      |> put_session("wt_chat_persona", persona)
      |> assign(:chat_identity, build_identity(conn, client_token, persona))

    conn
  end

  defp build_identity(conn, client_token, persona) do
    secret = Application.get_env(:whale_chat, :chat_ip_secret, "changeme")
    iphash = short_hash("#{secret}|#{client_token}")

    %{
      steamid: nil,
      personaname: persona["display"],
      persona: persona,
      iphash: iphash,
      rate_key: client_token,
      remote_ip: remote_ip_string(conn),
      server_ip: Application.get_env(:whale_chat, :chat_server_ip, "127.0.0.1"),
      server_port: Application.get_env(:whale_chat, :chat_server_port, 443)
    }
  end

  defp short_hash(value) do
    :sha256 |> :crypto.hash(value) |> Base.encode16(case: :lower) |> String.slice(0, 8)
  end

  defp remote_ip_string(conn) do
    conn.remote_ip
    |> Tuple.to_list()
    |> Enum.join(".")
  rescue
    _ -> ""
  end
end
