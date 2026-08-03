defmodule KogasaFrontend.Chat.NameStyle do
  @moduledoc false

  alias KogasaFrontend.Chat.MoreColors

  @gradient_pattern ~r/\Agradient:([a-z]+):([a-z]+)\z/i

  def from_preference(nil), do: nil

  def from_preference(preference) when is_map(preference) do
    pattern = preference |> value(:pattern) |> normalize()
    color = preference |> value(:color) |> normalize()

    case pattern do
      "america" ->
        %{kind: :america}

      _ ->
        gradient(pattern) || solid(color)
    end
  end

  def from_preference(_), do: nil

  defp gradient(pattern) do
    with [_, first_name, second_name] <- Regex.run(@gradient_pattern, pattern),
         first when is_binary(first) <- MoreColors.css(first_name),
         second when is_binary(second) <- MoreColors.css(second_name) do
      %{kind: :gradient, first: first, second: second}
    else
      _ -> nil
    end
  end

  defp solid(color) do
    case MoreColors.css(color) do
      value when is_binary(value) -> %{kind: :solid, color: value}
      _ -> nil
    end
  end

  defp value(preference, key),
    do: Map.get(preference, key) || Map.get(preference, Atom.to_string(key))

  defp normalize(value) when is_binary(value), do: value |> String.trim() |> String.downcase()
  defp normalize(_), do: ""
end
