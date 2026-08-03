defmodule KogasaFrontend.DisplayFormat do
  @moduledoc false

  import KogasaFrontend.Value, only: [float: 1, int: 1]

  def integer(value) do
    value
    |> int()
    |> Integer.to_string()
    |> String.reverse()
    |> String.replace(~r/(.{3})(?=.)/, "\\1,")
    |> String.reverse()
  end

  def decimal(value, digits \\ 1) do
    value
    |> float()
    |> :erlang.float_to_binary(decimals: max(0, digits))
  end

  def signed_decimal(value, digits \\ 1) do
    number = float(value)
    sign = if number > 0.0, do: "+", else: ""
    sign <> decimal(number, digits)
  end

  def duration(seconds, opts \\ []) do
    seconds = max(0, int(seconds))

    minimum_minutes =
      if seconds > 0, do: max(0, Keyword.get(opts, :minimum_minutes, 0)), else: 0

    show_zero_minutes = Keyword.get(opts, :show_zero_minutes, false)
    total_minutes = max(div(seconds, 60), minimum_minutes)
    hours = div(total_minutes, 60)
    minutes = rem(total_minutes, 60)

    cond do
      hours > 0 and (minutes > 0 or show_zero_minutes) -> "#{hours}h #{minutes}m"
      hours > 0 -> "#{hours}h"
      true -> "#{minutes}m"
    end
  end
end
