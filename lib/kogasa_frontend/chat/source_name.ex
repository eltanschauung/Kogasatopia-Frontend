defmodule KogasaFrontend.Chat.SourceName do
  @moduledoc false
  import Bitwise

  # Match Filters' eight-step gradients and discrete flag palettes. Bound the
  # plain relay name so color codes plus " | Web" fit its 128-byte outbox reader.
  @palettes %{
    america: [
      0xFFFFFF,
      0x1E90FF,
      0xFFFFFF,
      0x1E90FF,
      0xFFFFFF,
      0x1E90FF,
      0xFF4040,
      0xFF4040,
      0xFFFFFF,
      0xFFFFFF,
      0xFF4040,
      0xFF4040
    ],
    map: [0x6495ED, 0x99CCFF, 0xFFFF5E, 0xFFFFFF, 0xFFFF5E, 0xFFC0CB, 0xFF69B4],
    trans: [0x5BCEFA, 0xFFFFFF, 0xF5A9B8],
    rainbow: [0xFF4040, 0xFFA500, 0xFFFF00, 0x3EFF3E, 0x99CCFF, 0x9370D8, 0xEE82EE]
  }

  def render(name, style) do
    glyphs =
      name
      |> String.codepoints()
      |> Enum.reduce_while([], fn glyph, acc ->
        if IO.iodata_length([acc, glyph]) <= 31, do: {:cont, acc ++ [glyph]}, else: {:halt, acc}
      end)

    count = length(glyphs)
    steps = min(count, 8)
    denominator = max(steps - 1, 1)

    glyphs
    |> Enum.with_index()
    |> Enum.map_reduce(:unset, fn {glyph, index}, previous ->
      rgb = color_at(style, index, count, steps, denominator)
      code = if rgb == previous, do: "", else: color_code(rgb)
      {[code, glyph], rgb}
    end)
    |> elem(0)
    |> then(&IO.iodata_to_binary([&1, "\x01"]))
  end

  defp color_at(%{kind: :solid, color: color}, _, _, _, _), do: rgb(color)

  defp color_at(
         %{kind: :gradient, first: first, second: second, completion: completion},
         i,
         n,
         steps,
         d
       ) do
    finish = max(div((n - 1) * completion + 99, 100), 1)
    step = min(div(i * max(steps - 1, 0), finish), max(steps - 1, 0))
    blend(rgb(first), rgb(second), step, d)
  end

  defp color_at(
         %{kind: :triple_gradient, first: first, second: second, third: third},
         i,
         n,
         steps,
         d
       ) do
    step = div(i * max(steps - 1, 0), max(n - 1, 1)) * 2

    if step <= d,
      do: blend(rgb(first), rgb(second), step, d),
      else: blend(rgb(second), rgb(third), step - d, d)
  end

  defp color_at(%{kind: kind}, i, n, _, _) when is_map_key(@palettes, kind) do
    palette = Map.fetch!(@palettes, kind)
    Enum.at(palette, div(i * length(palette), max(n, 1)))
  end

  defp color_at(_, _, _, _, _), do: nil

  defp rgb("#" <> value), do: String.to_integer(value, 16)

  defp blend(a, b, step, d) do
    Enum.reduce([16, 8, 0], 0, fn shift, acc ->
      channel =
        div((a >>> shift &&& 255) * (d - step) + (b >>> shift &&& 255) * step + div(d, 2), d)

      acc ||| channel <<< shift
    end)
  end

  defp color_code(nil), do: "\x01"

  defp color_code(rgb),
    do: "\x07" <> (rgb |> Integer.to_string(16) |> String.upcase() |> String.pad_leading(6, "0"))
end
