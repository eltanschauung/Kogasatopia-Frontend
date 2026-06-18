defmodule KogasaFrontendWeb.Plugs.EnforceHttps do
  @moduledoc false
  import Plug.Conn

  alias KogasaFrontend.FastdlSite

  @local_hosts MapSet.new(["127.0.0.1", "localhost"])
  @hsts "max-age=31536000"

  def init(opts), do: opts

  def call(conn, _opts) do
    host = String.downcase(conn.host || "")

    cond do
      MapSet.member?(@local_hosts, host) ->
        conn

      FastdlSite.fastdl_host?(host) ->
        conn

      conn.scheme == :https ->
        register_before_send(conn, &put_resp_header(&1, "strict-transport-security", @hsts))

      true ->
        conn
        |> put_resp_header("location", https_location(conn))
        |> send_resp(301, "")
        |> halt()
    end
  end

  defp https_location(conn) do
    query =
      case conn.query_string do
        "" -> ""
        nil -> ""
        qs -> "?" <> qs
      end

    "https://" <> conn.host <> conn.request_path <> query
  end
end
