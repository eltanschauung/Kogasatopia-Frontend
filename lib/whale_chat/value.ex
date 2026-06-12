defmodule WhaleChat.Value do
  @moduledoc false

  def str(nil), do: ""
  def str(value) when is_binary(value), do: value
  def str(value), do: to_string(value)

  def int(nil), do: 0
  def int(value) when is_integer(value), do: value
  def int(value) when is_float(value), do: trunc(value)
  def int(%Decimal{} = value), do: value |> Decimal.round(0) |> Decimal.to_integer()

  def int(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> 0
    end
  end

  def int(_), do: 0

  def float(nil), do: 0.0
  def float(value) when is_float(value), do: value
  def float(value) when is_integer(value), do: value / 1
  def float(%Decimal{} = value), do: Decimal.to_float(value)

  def float(value) when is_binary(value) do
    case Float.parse(value) do
      {float, _} ->
        float

      :error ->
        case Integer.parse(value) do
          {int, _} -> int / 1
          :error -> 0.0
        end
    end
  end

  def float(_), do: 0.0

  def truthy?(value) when value in [true, 1, "1", "true", "yes", "on"], do: true
  def truthy?(_), do: false
end
