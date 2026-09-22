defmodule KogasaFrontend.ValveKeyValues do
  @moduledoc false

  def load_file(path) do
    with {:ok, body} <- File.read(path) do
      body
      |> tokenize()
      |> parse_entries()
      |> elem(0)
    else
      _ -> []
    end
  end

  def section(nil, _key), do: nil

  def section(entries, key) do
    Enum.find_value(entries, fn
      {^key, children} when is_list(children) -> children
      _ -> nil
    end)
  end

  def value(entries, key, default \\ "") do
    Enum.find_value(entries, default, fn
      {^key, value} when is_binary(value) -> String.trim(value)
      _ -> nil
    end)
  end

  defp tokenize(body) do
    body
    |> String.split("\n")
    |> Enum.flat_map(fn line ->
      line
      |> strip_comment()
      |> line_tokens()
    end)
  end

  defp strip_comment(line) do
    line
    |> String.to_charlist()
    |> strip_comment(false, [])
    |> Enum.reverse()
    |> to_string()
  end

  defp strip_comment([], _quoted, acc), do: acc
  defp strip_comment([?/, ?/ | _], false, acc), do: acc
  defp strip_comment([?" | rest], quoted, acc), do: strip_comment(rest, not quoted, [?" | acc])
  defp strip_comment([char | rest], quoted, acc), do: strip_comment(rest, quoted, [char | acc])

  defp line_tokens(line) do
    ~r/"([^"]*)"|([{}])/
    |> Regex.scan(line)
    |> Enum.map(fn
      ["{", "", "{"] -> :open
      ["}", "", "}"] -> :close
      [_, value] -> {:string, value}
      [_, value, ""] -> {:string, value}
      [_, "", "{"] -> :open
      [_, "", "}"] -> :close
    end)
  end

  defp parse_entries(tokens), do: parse_entries(tokens, [])

  defp parse_entries([], acc), do: {Enum.reverse(acc), []}
  defp parse_entries([:close | rest], acc), do: {Enum.reverse(acc), rest}

  defp parse_entries([{:string, key}, :open | rest], acc) do
    {children, rest} = parse_entries(rest, [])
    parse_entries(rest, [{key, children} | acc])
  end

  defp parse_entries([{:string, key}, {:string, value} | rest], acc) do
    parse_entries(rest, [{key, value} | acc])
  end

  defp parse_entries([_ | rest], acc), do: parse_entries(rest, acc)
end
