defmodule KogasaFrontend.WeaponCategories do
  @moduledoc false

  @categories [
    {"shotguns", %{label: "Shotgun"}},
    {"scatterguns", %{label: "Scattergun"}},
    {"pistols", %{label: "Pistol"}},
    {"rocketlaunchers", %{label: "Rocket Launcher"}},
    {"grenadelaunchers", %{label: "Grenade Launcher"}},
    {"stickylaunchers", %{label: "Sticky Launcher"}},
    {"snipers", %{label: "Sniper Rifle"}},
    {"revolvers", %{label: "Revolver"}}
  ]

  @metadata Map.new(@categories)
  @slugs Enum.map(@categories, &elem(&1, 0))

  def metadata, do: @metadata
  def slugs, do: @slugs
end
