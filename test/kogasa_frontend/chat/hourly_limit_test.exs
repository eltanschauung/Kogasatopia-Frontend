defmodule KogasaFrontend.Chat.HourlyLimitTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias KogasaFrontend.Chat
  alias KogasaFrontend.Chat.RateLimiter
  alias KogasaFrontendWeb.ChatApiController

  defp actor do
    token = "hourly-test-#{System.unique_integer([:positive])}"
    %{remote_ip: nil, rate_key: token, iphash: token}
  end

  defp quota_key(kind, identity) do
    digest = :crypto.hash(:sha256, identity) |> Base.encode16(case: :lower)
    "chat-volume:#{kind}:" <> digest
  end

  defp fill_quota(actor) do
    key = quota_key("browser", actor.rate_key)
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

  test "switching browsers cannot bypass an exhausted IP quota" do
    first = %{actor() | remote_ip: "198.51.100.12"}
    second = %{actor() | remote_ip: first.remote_ip}
    ip_key = quota_key("ip", first.remote_ip)
    assert Enum.all?(1..5, fn _ -> RateLimiter.allow_count?(ip_key, 5, 3600) end)

    capture_log(fn ->
      assert Chat.submit_message(first, "Hello again") == {:error, :hourly_rate_limited}
      assert Chat.submit_message(second, "Hello again") == {:error, :hourly_rate_limited}
    end)

    refute RateLimiter.at_count_limit?(quota_key("browser", second.rate_key), 1, 3600)
  end

  test "changing IP cannot bypass an exhausted browser quota" do
    first = actor()
    fill_quota(first)
    moved = %{first | remote_ip: "198.51.100.13"}

    capture_log(fn ->
      assert Chat.submit_message(moved, "Hello again") == {:error, :hourly_rate_limited}
    end)

    refute RateLimiter.at_count_limit?(quota_key("ip", moved.remote_ip), 1, 3600)
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
