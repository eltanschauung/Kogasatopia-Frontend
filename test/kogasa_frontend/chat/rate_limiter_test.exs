defmodule KogasaFrontend.Chat.RateLimiterTest do
  use ExUnit.Case, async: false

  alias KogasaFrontend.Chat.RateLimiter

  test "atomically limits repeated events within a counted window" do
    key = "test-repeat-#{System.unique_integer([:positive])}"

    allowed =
      1..20
      |> Task.async_stream(
        fn _ -> RateLimiter.allow_count?(key, 3, 300) end,
        max_concurrency: 20,
        ordered: false
      )
      |> Enum.count(&match?({:ok, true}, &1))

    assert allowed == 3
    refute RateLimiter.allow_count?(key, 3, 300)
  end

  test "limits sustained message volume within a counted window" do
    key = "test-volume-#{System.unique_integer([:positive])}"

    assert Enum.all?(1..15, fn _ -> RateLimiter.allow_count?(key, 15, 180) end)
    refute RateLimiter.allow_count?(key, 15, 180)
  end

  test "atomically permits only five messages in an hour" do
    key = "test-hourly-#{System.unique_integer([:positive])}"

    allowed =
      1..20
      |> Task.async_stream(fn _ -> RateLimiter.allow_count?(key, 5, 3600) end,
        max_concurrency: 20,
        ordered: false
      )
      |> Enum.count(&match?({:ok, true}, &1))

    assert allowed == 5
    refute RateLimiter.allow_count?(key, 5, 3600)
  end

  test "the hourly window expires individual messages rather than resetting on the clock hour" do
    key = "test-hourly-expiry-#{System.unique_integer([:positive])}"
    now = System.system_time(:second)

    :sys.replace_state(RateLimiter, fn state ->
      :ets.insert(
        :kogasa_frontend_counted_rate_limits,
        {key, now + 3600, [now, now, now, now, now - 3600]}
      )

      state
    end)

    assert RateLimiter.allow_count?(key, 5, 3600)
    refute RateLimiter.allow_count?(key, 5, 3600)
  end
end
