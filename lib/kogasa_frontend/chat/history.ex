defmodule KogasaFrontend.Chat.History do
  @moduledoc false
  @limit 500
  def limit, do: @limit
  def append(current, incoming), do: window(current ++ incoming, :newest)
  def prepend(current, older), do: window(older ++ current, :oldest)

  defp window(messages, direction) do
    sorted =
      messages
      |> Enum.filter(&(is_integer(&1[:id]) and &1.id > 0))
      |> Enum.uniq_by(& &1.id)
      |> Enum.sort_by(& &1.id)

    if direction == :oldest, do: Enum.take(sorted, @limit), else: Enum.take(sorted, -@limit)
  end
end
