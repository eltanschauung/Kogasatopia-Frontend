defmodule KogasaFrontendWeb.Plugs.AccessLog do
  @moduledoc false

  import Plug.Conn

  alias KogasaFrontend.AccessLog

  @months ~w(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)

  def init(opts), do: opts

  def call(conn, _opts) do
    register_before_send(conn, fn conn ->
      AccessLog.write(format_line(conn))
      conn
    end)
  end

  @doc false
  def format_line(conn) do
    [
      remote_ip(conn),
      " - - [",
      timestamp(),
      "] \"",
      escape(request_line(conn)),
      "\" ",
      status(conn),
      " ",
      response_size(conn),
      " \"",
      escape(safe_referrer(header(conn, "referer")), 1024),
      "\" \"",
      escape(header(conn, "user-agent"), 512),
      "\"\n"
    ]
    |> IO.iodata_to_binary()
  rescue
    _ -> "- - - [#{timestamp()}] \"-\" 0 - \"-\" \"-\"\n"
  end

  defp remote_ip(%Plug.Conn{remote_ip: remote_ip}) do
    remote_ip
    |> :inet.ntoa()
    |> to_string()
  rescue
    _ -> "-"
  end

  defp timestamp do
    now = DateTime.utc_now()
    month = Enum.at(@months, now.month - 1)

    :io_lib.format(
      "~2..0B/~s/~4..0B:~2..0B:~2..0B:~2..0B +0000",
      [now.day, month, now.year, now.hour, now.minute, now.second]
    )
    |> IO.iodata_to_binary()
  end

  defp request_line(conn) do
    # Queries can contain Steam OpenID proofs and game-panel bearer tokens.
    # Omit all query values rather than chasing a blacklist of credential names.
    path = KogasaFrontend.LogPrivacy.path(conn.request_path)

    conn.method <>
      " " <>
      binary_part(path, 0, min(byte_size(path), 2048)) <> " HTTP/1.1"
  end

  defp status(conn) do
    conn.status
    |> Kernel.||(0)
    |> Integer.to_string()
  end

  defp response_size(conn) do
    case get_resp_header(conn, "content-length") do
      [length | _] ->
        length

      [] ->
        body_size(conn.resp_body)
    end
  end

  defp body_size(nil), do: "-"

  defp body_size(body) do
    body
    |> IO.iodata_length()
    |> Integer.to_string()
  rescue
    _ -> "-"
  end

  defp header(conn, name) do
    case get_req_header(conn, name) do
      [value | _] when value != "" -> value
      _ -> "-"
    end
  end

  defp safe_referrer(value) do
    case URI.parse(value) do
      %URI{scheme: scheme, host: host} = uri
      when scheme in ["http", "https"] and is_binary(host) ->
        %{
          uri
          | userinfo: nil,
            query: nil,
            fragment: nil,
            path: KogasaFrontend.LogPrivacy.path(uri.path)
        }
        |> URI.to_string()

      _ ->
        "-"
    end
  rescue
    _ -> "-"
  end

  defp escape(value, limit \\ 3072) do
    value
    |> to_string()
    |> then(fn value -> binary_part(value, 0, min(byte_size(value), limit)) end)
    |> String.replace("\\", "\\\\")
    |> String.replace("\"", "\\\"")
    |> String.replace(~r/[\x00-\x1f\x7f]/, " ")
  end
end
