defmodule KogasaFrontend.LogPrivacy do
  @moduledoc false
  @panel "/api/weapons/panel/"

  def path(value) when is_binary(value) do
    case URI.decode(value) do
      @panel <> rest ->
        suffix =
          case String.split(rest, "/") do
            [_token, "actions"] -> "/actions"
            [_token, "actions", _id] -> "/actions/[ACTION]"
            _ -> ""
          end

        @panel <> "[FILTERED]" <> suffix

      _ ->
        value
    end
  rescue
    _ -> "-"
  end

  def path(value), do: value

  # Phoenix's standard request line is logged before parameter filtering; these
  # capability routes remain observable in our redacted combined access log.
  def request_level(conn) do
    if path(conn.request_path) == conn.request_path, do: :info, else: false
  end
end
