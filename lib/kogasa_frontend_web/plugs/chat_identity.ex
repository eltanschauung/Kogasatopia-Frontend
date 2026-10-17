defmodule KogasaFrontendWeb.Plugs.ChatIdentity do
  @moduledoc false
  import Plug.Conn
  alias KogasaFrontend.Chat
  alias KogasaFrontend.Chat.Identity

  @parsee_web_subnet "70.175.0.0/16"

  def init(opts), do: opts

  def call(conn, _opts) do
    client_token =
      get_session(conn, "wt_chat_client_token") ||
        :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)

    persona = Chat.ensure_session_persona(get_session(conn, "wt_chat_persona"))
    source_subnet = source_subnet_for_ip(conn.remote_ip)

    conn =
      conn
      |> put_session("wt_chat_client_token", client_token)
      |> put_session("wt_chat_persona", persona)
      |> put_session("wt_chat_source_subnet", source_subnet)
      |> assign(:chat_identity, build_identity(conn, client_token, persona, source_subnet))

    conn
  end

  defp build_identity(conn, client_token, persona, source_subnet) do
    conn
    |> get_session()
    |> Map.put("wt_chat_client_token", client_token)
    |> Identity.from_session(persona)
    |> Map.merge(%{
      remote_ip: remote_ip_string(conn.remote_ip),
      source_subnet: source_subnet
    })
  end

  def remote_ip_string(address) when is_tuple(address) do
    address
    |> Tuple.to_list()
    |> Enum.join(".")
  rescue
    _ -> ""
  end

  def remote_ip_string(_address), do: ""

  def source_subnet_for_ip({70, 175, _, _}), do: @parsee_web_subnet
  def source_subnet_for_ip({0, 0, 0, 0, 0, 0xFFFF, 0x46AF, _}), do: @parsee_web_subnet
  def source_subnet_for_ip(_address), do: nil
end
