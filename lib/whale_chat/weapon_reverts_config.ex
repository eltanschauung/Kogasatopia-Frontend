defmodule WhaleChat.WeaponRevertsConfig do
  @moduledoc false

  @item_classes_section "WeaponRevertsItemClasses"
  @root_section "WeaponReverts"
  @config_filename "weaponreverts.cfg"
  @repo_fallback "/home/kogasa/Kogasatopia/tf/addons/sourcemod/configs/weaponreverts.cfg"

  def items_by_class(classes, path \\ config_path()) do
    root = load_root(path)
    class_map = section(root, @item_classes_section) || []
    weapon_sections = weapon_sections(root)

    Enum.into(classes, %{}, fn %{key: class_key} ->
      {class_key, class_items(class_map, class_key, weapon_sections)}
    end)
  end

  def config_path do
    cwd_config = Path.expand(@config_filename, File.cwd!())

    cond do
      File.exists?(cwd_config) -> cwd_config
      File.exists?(@repo_fallback) -> @repo_fallback
      true -> cwd_config
    end
  end

  defp load_root(path) do
    with {:ok, body} <- File.read(path) do
      body
      |> tokenize()
      |> parse_entries()
      |> elem(0)
      |> root_entries()
    else
      _ -> []
    end
  end

  defp root_entries(entries), do: section(entries, @root_section) || entries

  defp weapon_sections(root) do
    keyed =
      root
      |> Enum.filter(fn
        {@item_classes_section, _} -> false
        {_, children} -> is_list(children)
      end)
      |> Map.new()

    tokenized =
      Enum.reduce(keyed, %{}, fn {item_key, children}, acc ->
        item_key
        |> split_item_key()
        |> Enum.reduce(acc, &Map.put_new(&2, &1, children))
      end)

    %{keyed: keyed, tokenized: tokenized}
  end

  defp class_items(class_map, class_key, weapon_sections) do
    class_map
    |> section(class_key)
    |> List.wrap()
    |> Enum.reduce({[], MapSet.new()}, fn {item_key, _}, {items, seen} ->
      case item_for_key(item_key, weapon_sections) do
        nil ->
          {items, seen}

        item ->
          dedupe_key = item_dedupe_key(item)

          if MapSet.member?(seen, dedupe_key) do
            {items, seen}
          else
            {[item | items], MapSet.put(seen, dedupe_key)}
          end
      end
    end)
    |> elem(0)
    |> Enum.reverse()
  end

  defp item_for_key(item_key, %{keyed: keyed, tokenized: tokenized}) do
    with children when is_list(children) <-
           Map.get(keyed, item_key) || Map.get(tokenized, item_key),
         item <- normalize_item(item_key, children),
         false <- blank_effects?(item) do
      item
    else
      _ -> nil
    end
  end

  defp normalize_item(item_key, children) do
    description = section(children, "change_description") || []

    %{
      key: item_key,
      name: value(children, "weapon_name", item_key),
      image: value(children, "image", ""),
      type: value(description, "type", ""),
      positive: value(description, "positive", ""),
      neutral: value(description, "neutral", ""),
      negative: value(description, "negative", "")
    }
  end

  defp blank_effects?(%{positive: positive, neutral: neutral, negative: negative}) do
    [positive, neutral, negative]
    |> Enum.map(&String.trim/1)
    |> Enum.all?(&(&1 == ""))
  end

  defp item_dedupe_key(%{
         name: name,
         positive: positive,
         neutral: neutral,
         negative: negative,
         image: image
       }) do
    Enum.join([name, positive, neutral, negative, image], "|")
  end

  defp section(nil, _key), do: nil

  defp section(entries, key) do
    Enum.find_value(entries, fn
      {^key, children} when is_list(children) -> children
      _ -> nil
    end)
  end

  defp value(entries, key, default) do
    Enum.find_value(entries, default, fn
      {^key, value} when is_binary(value) -> String.trim(value)
      _ -> nil
    end)
  end

  defp split_item_key(item_key) do
    item_key
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
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
