defmodule KogasaFrontend.Chat.HourlyLimitTest do
  use ExUnit.Case, async: false

  alias KogasaFrontend.Chat
  alias KogasaFrontend.Chat.RateLimiter
  alias KogasaFrontendWeb.ChatApiController

  defp actor do
    token = "hourly-test-#{System.unique_integer([:positive])}"
    %{remote_ip: nil, rate_key: token, iphash: token}
  end

  defp fill_quota(actor) do
    identity = actor.remote_ip || actor.rate_key
    digest = :crypto.hash(:sha256, identity <> "|" <> actor.rate_key)
    key = "chat-volume:" <> Base.encode16(digest, case: :lower)
    assert Enum.all?(1..5, fn _ -> RateLimiter.allow_count?(key, 5, 3600) end)
  end

  test "full hourly quota blocks without adding spam-ban strikes or consuming other limits" do
    actor = actor()
    fill_quota(actor)

    for _ <- 1..4 do
      assert Chat.submit_message(actor, "Hello there") == {:error, :hourly_rate_limited}
    end

    assert RateLimiter.allow?("chat:" <> actor.rate_key, 5)
    assert Chat.hourly_limit_message() == "Error: Messages are limited to 5/hour per individual."
  end

  test "IP and browser session together identify the hourly quota" do
    first = actor()
    fill_quota(first)

    second = %{first | rate_key: "#{first.rate_key}-other-browser"}
    fill_quota(second)

    moved = %{first | remote_ip: "198.51.100.12"}
    fill_quota(moved)

    assert Chat.submit_message(first, "Hello again") == {:error, :hourly_rate_limited}
    assert Chat.submit_message(second, "Hello again") == {:error, :hourly_rate_limited}
  end

  test "chat API returns HTTP 429 and the requested warning" do
    actor = actor()
    fill_quota(actor)

    conn =
      Plug.Test.conn(:post, "/stats/chat.php", %{"message" => "Hello there"})
      |> Plug.Conn.assign(:chat_identity, actor)
      |> ChatApiController.create(%{})

    assert conn.status == 429

    assert Jason.decode!(conn.resp_body) == %{
             "ok" => false,
             "error" => "hourly_rate",
             "message" => "Error: Messages are limited to 5/hour per individual."
           }
  end

  test "LiveView uses the same hourly warning" do
    actor = actor()
    fill_quota(actor)
    socket = %Phoenix.LiveView.Socket{assigns: %{identity: actor, __changed__: %{}}}

    assert {:noreply, socket} =
             KogasaFrontendWeb.ChatLive.handle_event(
               "send",
               %{"message" => "Hello there"},
               socket
             )

    assert socket.assigns.status == Chat.hourly_limit_message()
  end
end
