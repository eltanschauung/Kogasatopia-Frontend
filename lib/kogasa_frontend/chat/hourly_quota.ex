defmodule KogasaFrontend.Chat.HourlyQuota do
  @moduledoc false

  def policy(actor) do
    browser = actor[:browser_key] || actor[:rate_key] || actor[:iphash] || "anon"
    keys = ["chat-volume:browser:" <> digest(browser)]

    keys =
      if present?(actor[:remote_ip]),
        do: ["chat-volume:ip:" <> digest(actor.remote_ip) | keys],
        else: keys

    keys =
      if present?(actor[:steamid]),
        do: ["chat-volume:steam:" <> digest(actor.steamid) | keys],
        else: keys

    # Keep the existing shared IP/browser counters. Signing in raises their
    # ceiling to ten, rather than resetting guest usage; logout cannot refill it.
    %{keys: keys, limit: if(present?(actor[:steamid]), do: 10, else: 5), window: 3600}
  end

  def message(actor) do
    "Error: Messages are limited to #{policy(actor).limit}/hour per individual."
  end

  defp present?(value), do: is_binary(value) and value != ""
  defp digest(value), do: :sha256 |> :crypto.hash(to_string(value)) |> Base.encode16(case: :lower)
end
