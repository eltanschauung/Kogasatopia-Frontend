defmodule KogasaFrontend.WeaponRevertsConfigTest do
  use ExUnit.Case, async: true

  alias KogasaFrontend.WeaponRevertsConfig

  @classes [
    %{key: "scout"},
    %{key: "soldier"},
    %{key: "heavy"}
  ]

  test "merges weaponreverts and cwx display data by class" do
    tmp = System.tmp_dir!()
    reverts_path = Path.join(tmp, "weaponreverts-test.cfg")
    cwx_path = Path.join(tmp, "weapons-test.txt")

    File.write!(reverts_path, """
    "WeaponReverts"
    {
      "WeaponRevertsItemClasses"
      {
        "scout"
        {
          "100" "1"
        }
      }
      "100"
      {
        "weapon_name" "Revert Gun"
        "image" "revert.png"
        "change_description"
        {
          "positive" "Buffed"
          "neutral" "Neutral note"
          "negative" "Nerfed"
        }
      }
    }
    """)

    File.write!(cwx_path, """
    "Items"
    {
      "custom_heavy"
      {
        "inherits" "TF_WEAPON_MINIGUN"
        "name" "Custom Heavy Gun"
        "image" "heavy.png"
        "description"
        {
          "positive" "Heavy positive"
          "neutral" ""
          "negative" ""
        }
      }
      "custom_soldier"
      {
        "inherits" "The Buff Banner"
        "name" "Custom Soldier Banner"
        "description"
        {
          "positive" ""
          "neutral" ""
          "negative" ""
        }
      }
    }
    """)

    items = WeaponRevertsConfig.items_by_class(@classes, reverts_path, cwx_path)

    assert [%{name: "Revert Gun"}] = items["scout"]

    assert [%{name: "Custom Heavy Gun", image: "heavy.png", positive: "Heavy positive"}] =
             items["heavy"]

    assert [
             %{
               name: "Custom Soldier Banner",
               image: "100px-item_icon_wrangler.png",
               positive: "",
               neutral: "",
               negative: ""
             }
           ] = items["soldier"]
  end
end
