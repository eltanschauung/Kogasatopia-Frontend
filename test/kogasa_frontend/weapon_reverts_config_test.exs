defmodule KogasaFrontend.WeaponRevertsConfigTest do
  use ExUnit.Case, async: true

  alias KogasaFrontend.WeaponRevertsConfig

  @classes [
    %{key: "scout"},
    %{key: "soldier"},
    %{key: "heavy"},
    %{key: "all_class"}
  ]

  test "merges weaponreverts and cwx display data by class" do
    tmp = System.tmp_dir!()
    config_path = Path.join(tmp, "weapons-test.cfg")

    File.write!(config_path, """
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
        "name" "Revert Gun"
        "image" "revert.png"
        "description"
        {
          "positive" "Buffed"
          "neutral" "Neutral note"
          "negative" "Nerfed"
        }
      }
      "CWX"
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
        "custom_all_class"
        {
          "all_class" "true"
          "name" "All Class Item"
          "description"
          {
            "positive" "Everyone can equip it"
            "neutral" ""
            "negative" ""
          }
        }
      }
    }
    """)

    items = WeaponRevertsConfig.items_by_class(@classes, config_path)

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

    assert [%{name: "All Class Item", positive: "Everyone can equip it"}] = items["all_class"]

    refute Enum.any?(items["scout"], &(&1.name == "All Class Item"))

    assert WeaponRevertsConfig.cwx_item_names(config_path) == %{
             "custom_heavy" => "Custom Heavy Gun",
             "custom_soldier" => "Custom Soldier Banner",
             "custom_all_class" => "All Class Item"
           }
  end
end
