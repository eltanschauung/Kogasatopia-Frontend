defmodule WhaleChat.UpstreamProxy do
  @moduledoc false

  def fetch_html(url) when is_binary(url) do
    args = ["-fsSL", "--connect-timeout", "2", "--max-time", "6", "--http1.1", url]

    case System.cmd("curl", args, stderr_to_stdout: true) do
      {body, 0} -> {:ok, body}
      {_output, _code} -> :error
    end
  end
end
