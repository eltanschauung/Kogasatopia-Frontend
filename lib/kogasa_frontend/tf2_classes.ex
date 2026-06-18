defmodule KogasaFrontend.Tf2Classes do
  @moduledoc false

  @leaderboard_base "/leaderboard/"

  @classes [
    %{
      id: 1,
      slug: "scout",
      label: "Scout",
      leaderboard_icon: "Scout.png",
      info_icon: "scout.png"
    },
    %{
      id: 2,
      slug: "sniper",
      label: "Sniper",
      leaderboard_icon: "Sniper.png",
      info_icon: "sniper.png"
    },
    %{
      id: 3,
      slug: "soldier",
      label: "Soldier",
      leaderboard_icon: "Soldier.png",
      info_icon: "soldier.png"
    },
    %{
      id: 4,
      slug: "demoman",
      label: "Demoman",
      leaderboard_icon: "Demoman.png",
      info_icon: "demoman.png"
    },
    %{
      id: 5,
      slug: "medic",
      label: "Medic",
      leaderboard_icon: "Medic.png",
      info_icon: "medic.png"
    },
    %{
      id: 6,
      slug: "heavy",
      label: "Heavy",
      leaderboard_icon: "Heavy.png",
      info_icon: "heavy.png"
    },
    %{id: 7, slug: "pyro", label: "Pyro", leaderboard_icon: "Pyro.png", info_icon: "pyro.png"},
    %{id: 8, slug: "spy", label: "Spy", leaderboard_icon: "Spy.png", info_icon: "spy.png"},
    %{
      id: 9,
      slug: "engineer",
      label: "Engineer",
      leaderboard_icon: "Engineer.png",
      info_icon: "engineer.png"
    }
  ]

  @spectator %{id: 0, slug: "spectator", label: "Spectator", leaderboard_icon: "Icon_replay.png"}
  @all_class_info %{id: 10, slug: "all_class", label: "All Class", info_icon: "backpack.png"}
  @info_class_order ~w(scout soldier pyro demoman heavy engineer medic sniper spy)
  @by_id Map.new(@classes, fn class -> {class.id, class} end)
  @by_label Map.new(@classes, fn class -> {class.label, class} end)

  def info_classes do
    info_classes =
      @classes
      |> Enum.sort_by(fn class ->
        Enum.find_index(@info_class_order, &(&1 == class.slug)) || 999
      end)
      |> Enum.map(fn class ->
        %{id: class.id, key: class.slug, label: class.label, icon: class.info_icon}
      end)

    info_classes ++
      [
        %{
          id: @all_class_info.id,
          key: @all_class_info.slug,
          label: @all_class_info.label,
          icon: @all_class_info.info_icon
        }
      ]
  end

  def online_metadata do
    [@spectator | @classes]
    |> Map.new(fn class ->
      {class.id, %{slug: class.slug, label: class.label, icon: class.leaderboard_icon}}
    end)
  end

  def leaderboard_icon_for_id(id) do
    id
    |> int_id()
    |> then(&Map.get(@by_id, &1))
    |> leaderboard_icon_tuple()
  end

  def leaderboard_icon_for_label(label) do
    label
    |> to_string()
    |> then(&Map.get(@by_label, &1))
    |> leaderboard_icon_tuple()
  end

  defp leaderboard_icon_tuple(nil), do: :error

  defp leaderboard_icon_tuple(class) do
    {:ok, {class.label, @leaderboard_base <> class.leaderboard_icon}}
  end

  defp int_id(value) when is_integer(value), do: value

  defp int_id(value) do
    case Integer.parse(to_string(value)) do
      {id, _} -> id
      _ -> 0
    end
  end
end
