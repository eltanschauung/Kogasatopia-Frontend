defmodule KogasaFrontend.Chat.Persona do
  @moduledoc false

  alias KogasaFrontend.Chat.WebName
  alias KogasaFrontend.Repo
  import Ecto.Query

  def ensure_persona(nil), do: random_persona()
  def ensure_persona(%{"display" => _} = persona), do: persona
  def ensure_persona(%{display: _} = persona), do: stringify_keys(persona)
  def ensure_persona(_), do: random_persona()

  def random_persona do
    case webnames() do
      [] ->
        tag = random_tag()

        %{
          "name" => "Guest-#{tag}",
          "color" => "{default}",
          "display" => "{gold}[Web]{default} Guest-#{tag}{default}"
        }

      names ->
        choice = Enum.random(names)

        display =
          ensure_default_suffix("{gold}[Web]{default} #{choice["color"]}#{choice["name"]}")

        Map.put(choice, "display", display)
    end
  end

  def webnames do
    try do
      Repo.all(
        from w in WebName, order_by: [asc: w.name], select: %{name: w.name, color: w.color}
      )
      |> Enum.map(fn %{name: name, color: color} ->
        %{"name" => String.trim(name || ""), "color" => String.trim(color || "")}
      end)
      |> Enum.filter(fn %{"name" => name, "color" => color} -> name != "" and color != "" end)
    rescue
      _ -> []
    end
  end

  def try_update_from_command(message) when is_binary(message) do
    case parse_command(message) do
      nil ->
        {:not_command, nil}

      query ->
        case find_option(query) do
          nil -> {:persona_not_found, webnames()}
          option -> {:persona_updated, persona_from_option(option)}
        end
    end
  end

  def parse_command("/name " <> rest), do: blank_to_nil(rest)
  def parse_command("/persona " <> rest), do: blank_to_nil(rest)

  def parse_command("/" <> rest) do
    blank_to_nil(rest)
  end

  def parse_command(_), do: nil

  defp blank_to_nil(value) do
    value = String.trim(value)
    if value == "", do: nil, else: value
  end

  defp find_option(query) do
    query = String.downcase(query)

    webnames()
    |> Enum.find(fn %{"name" => name} ->
      String.contains?(String.downcase(name), query)
    end)
  end

  defp persona_from_option(%{"name" => name, "color" => color}) do
    %{
      "name" => name,
      "color" => color,
      "display" => ensure_default_suffix("{gold}[Web]{default} #{color}#{name}")
    }
  end

  defp ensure_default_suffix(display) do
    if String.ends_with?(display, "{default}"), do: display, else: display <> "{default}"
  end

  defp random_tag do
    3 |> :crypto.strong_rand_bytes() |> Base.encode16(case: :lower)
  end

  defp stringify_keys(map) do
    Map.new(map, fn {k, v} -> {to_string(k), v} end)
  end
end
