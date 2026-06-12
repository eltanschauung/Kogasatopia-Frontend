defmodule WhaleChatWeb.Plugs.AccessLog do
  @moduledoc false

  import Plug.Conn

  alias WhaleChat.AccessLog

  @months ~w(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)

  def init(opts), do: opts

  def call(conn, _opts) do
    register_before_send(conn, fn conn ->
      AccessLog.write(format_line(conn))
      conn
    end)
  end

  defp format_line(conn) do
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
      escape(header(conn, "referer")),
      "\" \"",
      escape(header(conn, "user-agent")),
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
    query = if conn.query_string in [nil, ""], do: "", else: "?" <> conn.query_string
    conn.method <> " " <> conn.request_path <> query <> " HTTP/1.1"
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

  defp escape(value) do
    value
    |> to_string()
    |> String.replace("\\", "\\\\")
    |> String.replace("\"", "\\\"")
    |> String.replace(~r/[\r\n\t]/, " ")
  end
end
