defmodule KogasaFrontend.Chat.NameStyle do
  @moduledoc false

  alias KogasaFrontend.Chat.MoreColors

  @gradient_default_completion 50
  @gradient_max_completion 90

  def from_preference(nil), do: nil

  def from_preference(preference) when is_map(preference) do
    pattern = preference |> value(:pattern) |> normalize()
    color = preference |> value(:color) |> normalize()

    case pattern do
      "america" ->
        %{kind: :america}

      "map" ->
        %{kind: :map}

      "trans" ->
        %{kind: :trans}

      "rainbow" ->
        %{kind: :rainbow}

      _ ->
        triple_gradient(pattern) || gradient(pattern) || solid(color)
    end
  end

  def from_preference(_), do: nil

  def custom?(%{kind: kind})
      when kind in [:gradient, :triple_gradient, :america, :map, :trans, :rainbow, :solid],
      do: true

  def custom?(_), do: false

  def css_class(%{kind: kind})
      when kind in [:gradient, :triple_gradient, :america, :map, :trans, :rainbow],
      do: "chat-name-gradient"

  def css_class(_), do: nil

  def css_style(%{kind: :gradient, first: first, second: second, completion: completion}),
    do:
      "color: transparent; --chat-name-gradient: linear-gradient(90deg, #{first} 0%, #{second} #{completion}%, #{second} 100%)"

  def css_style(%{kind: :triple_gradient, first: first, second: second, third: third}),
    do:
      "color: transparent; --chat-name-gradient: linear-gradient(90deg, #{first} 0%, #{second} 50%, #{third} 100%)"

  def css_style(%{kind: :america}),
    do:
      "color: transparent; --chat-name-gradient: linear-gradient(90deg, #FF4040 0%, #FF4040 33.333%, #FFFFFF 33.333%, #FFFFFF 66.666%, #1E90FF 66.666%, #1E90FF 100%)"

  def css_style(%{kind: :map}),
    do:
      "color: transparent; --chat-name-gradient: linear-gradient(90deg, #99CCFF 0%, #99CCFF 12.5%, #6495ED 12.5%, #6495ED 25%, #FFFFE0 25%, #FFFFE0 37.5%, #FFFFFF 37.5%, #FFFFFF 62.5%, #FFFFE0 62.5%, #FFFFE0 75%, #FFC0CB 75%, #FFC0CB 87.5%, #FF69B4 87.5%, #FF69B4 100%)"

  def css_style(%{kind: :trans}),
    do:
      "color: transparent; --chat-name-gradient: linear-gradient(90deg, #5BCEFA 0%, #5BCEFA 33.333%, #FFFFFF 33.333%, #FFFFFF 66.666%, #F5A9B8 66.666%, #F5A9B8 100%)"

  def css_style(%{kind: :rainbow}),
    do:
      "color: transparent; --chat-name-gradient: linear-gradient(90deg, #FF4040, #FFA500, #FFFF00, #3EFF3E, #99CCFF, #4B0082, #EE82EE)"

  def css_style(%{kind: :solid, color: color}), do: "color: #{color}"
  def css_style(_), do: nil

  defp gradient(pattern) do
    with {:ok, first_name, second_name, completion} <- gradient_parts(pattern),
         first when is_binary(first) <- MoreColors.css(first_name),
         second when is_binary(second) <- MoreColors.css(second_name) do
      %{kind: :gradient, first: first, second: second, completion: completion}
    else
      _ -> nil
    end
  end

  defp triple_gradient(pattern) do
    with ["gradient3", first_name, second_name, third_name] <- String.split(pattern, ":"),
         first when is_binary(first) <- MoreColors.css(first_name),
         second when is_binary(second) <- MoreColors.css(second_name),
         third when is_binary(third) <- MoreColors.css(third_name) do
      %{kind: :triple_gradient, first: first, second: second, third: third}
    else
      _ -> nil
    end
  end

  defp gradient_parts(pattern) do
    case String.split(pattern, ":") do
      ["gradient", first, second] ->
        {:ok, first, second, @gradient_default_completion}

      ["gradient", first, second, percentage] ->
        case Integer.parse(percentage) do
          {value, ""} when value > 0 and value <= @gradient_max_completion ->
            {:ok, first, second, value}

          _ ->
            :error
        end

      _ ->
        :error
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
