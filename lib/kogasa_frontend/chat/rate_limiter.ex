defmodule KogasaFrontend.Chat.RateLimiter do
  @moduledoc false
  use GenServer

  @table :kogasa_frontend_rate_limits

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def allow?(key, ttl_seconds)
      when is_binary(key) and is_integer(ttl_seconds) and ttl_seconds > 0 do
    now = System.system_time(:second)
    expires_at = now + ttl_seconds

    case :ets.lookup(@table, key) do
      [{^key, existing_expiry}] when existing_expiry > now ->
        false

      _ ->
        :ets.insert(@table, {key, expires_at})
        true
    end
  end

  @impl true
  def init(state) do
    :ets.new(@table, [
      :named_table,
      :public,
      :set,
      read_concurrency: true,
      write_concurrency: true
    ])

    schedule_cleanup()
    {:ok, state}
  end

  @impl true
  def handle_info(:cleanup, state) do
    now = System.system_time(:second)
    :ets.select_delete(@table, [{{:"$1", :"$2"}, [{:<, :"$2", now}], [true]}])
    schedule_cleanup()
    {:noreply, state}
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, :timer.seconds(30))
  end
end
