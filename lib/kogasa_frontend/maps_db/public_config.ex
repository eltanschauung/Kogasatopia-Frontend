defmodule KogasaFrontend.MapsDb.PublicConfig do
  @moduledoc """
  Bounded public config reads with conservative known-secret redaction.
  This is not a secret-free export policy: plugin-specific unknown secrets must
  still be removed from published files by their operator.
  """
  @max_bytes 1_048_576
  @secret ~r/\b(?:[a-z0-9_]*(?:password|passwd|secret|token|api_?key|auth_?key|credential|webhook)[a-z0-9_]*|sv_setsteamaccount|sm_gslt)\b|https?:\/\/[^\s\/"']+@/i

  def read(path) do
    case File.open(path, [:read, :binary], fn io -> IO.binread(io, @max_bytes + 1) end) do
      {:ok, :eof} ->
        {:ok, ""}

      {:ok, content} when is_binary(content) and byte_size(content) <= @max_bytes ->
        if String.valid?(content), do: {:ok, content}, else: {:error, :invalid_config}

      {:ok, content} when is_binary(content) ->
        {:error, :config_too_large}

      {:ok, {:error, _} = error} ->
        error

      {:error, _} = error ->
        error
    end
  end

  # Commands can contain quoted semicolons/newlines or nested alias text. Redact
  # the entire containing statement, not just the first word/value on one line.
  def redact(content), do: scan(content, [], [], false, false, false)

  defp scan(<<>>, command, output, _quoted, _escaped, _comment),
    do: IO.iodata_to_binary(Enum.reverse([redact_command(command) | output]))

  defp scan(<<"//", rest::binary>>, command, output, false, false, _comment),
    do: scan(rest, ["//" | command], output, false, false, true)

  defp scan(<<char, rest::binary>>, command, output, quoted, escaped, comment) do
    cond do
      char == ?\n and comment ->
        flush(rest, command, output, "\n")

      char in [?\n, ?;] and not quoted and not comment ->
        flush(rest, command, output, <<char>>)

      char == ?" and not escaped and not comment ->
        scan(rest, [char | command], output, not quoted, false, comment)

      true ->
        scan(
          rest,
          [char | command],
          output,
          quoted,
          char == ?\\ and not escaped and not comment,
          comment
        )
    end
  end

  defp flush(rest, command, output, delimiter),
    do: scan(rest, [], [delimiter, redact_command(command) | output], false, false, false)

  defp redact_command(command) do
    text = command |> Enum.reverse() |> IO.iodata_to_binary()
    if Regex.match?(@secret, text), do: "// [redacted sensitive directive]", else: text
  end
end
