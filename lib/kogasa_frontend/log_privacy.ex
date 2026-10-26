defmodule KogasaFrontend.LogPrivacy do
  @moduledoc false
  @panel "/api/weapons/panel/"

  def path(value) when is_binary(value) do
    case classify(value) do
      {:panel, rest} ->
        suffix =
          case rest do
            [_token, "actions"] -> "/actions"
            [_token, "actions", _id] -> "/actions/[ACTION]"
            _ -> ""
          end

        @panel <> "[FILTERED]" <> suffix

      :ordinary ->
        value

      :invalid ->
        "-"
    end
  end

  def path(value), do: value

  # Phoenix's standard request line is logged before parameter filtering; these
  # capability routes remain observable in our redacted combined access log.
  def request_level(conn) do
    if classify(conn.request_path) == :ordinary, do: :info, else: false
  end

  defp classify(value) do
    # Plug removes empty segments before Phoenix routes the request. Decode then
    # split here, conservatively including encoded separators, so equivalent or
    # malformed panel paths never escape request/Referer/framework redaction.
    case value |> URI.decode() |> String.split("/", trim: true) do
      ["api", "weapons", "panel" | rest] -> {:panel, rest}
      _ -> :ordinary
    end
  rescue
    _ -> :invalid
  end
end
