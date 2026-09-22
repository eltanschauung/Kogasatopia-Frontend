defmodule KogasaFrontend.CustomHatPopularityTest do
  use ExUnit.Case, async: true

  alias KogasaFrontend.CustomHatPopularity
  alias KogasaFrontend.CustomHatsConfig

  setup do
    directory =
      Path.join(
        System.tmp_dir!(),
        "kogasa-custom-hats-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(directory)
    on_exit(fn -> File.rm_rf!(directory) end)

    config_path = Path.join(directory, "custom_hats.cfg")
    database_path = Path.join(directory, "clientprefs.sq3")

    File.write!(config_path, """
    "CustomHats"
    {
        "hats"
        {
            "mercenary_derby"
            {
                "name" "Mercenary Derby"
                "soldier"
                {
                    "defindex" "360"
                }
            }
            "punishing_bird"
            {
                "name" "Punishing Bird"
            }
            "single_hat"
            {
                "name" "Only One User"
            }
        }
    }
    """)

    sqlite3 = System.find_executable("sqlite3") || flunk("sqlite3 is required")

    sql = """
    CREATE TABLE sm_cookies (
      id INTEGER PRIMARY KEY,
      name varchar(30) NOT NULL UNIQUE,
      description varchar(255),
      access INTEGER
    );
    CREATE TABLE sm_cookie_cache (
      player varchar(65) NOT NULL,
      cookie_id INTEGER NOT NULL,
      value varchar(100),
      timestamp INTEGER,
      PRIMARY KEY (player, cookie_id)
    );
    INSERT INTO sm_cookies (id, name) VALUES
      (1, 'custom_hats_state'),
      (2, 'custom_hats_state_2');
    INSERT INTO sm_cookie_cache (player, cookie_id, value, timestamp) VALUES
      ('player-a', 1, 'mercenary_derby:0,punishing_bird:0,single_hat:0', 1),
      ('player-b', 1, 'mercenary_derby:2', 1),
      ('player-c', 2, 'punishing_bird:0', 1),
      ('player-d', 1, '0,3,1,0', 1),
      ('player-e', 1, '1|punishing_bird|0', 1);
    """

    assert {_, 0} = System.cmd(sqlite3, [database_path, sql], stderr_to_stdout: true)

    %{config_path: config_path, database_path: database_path}
  end

  test "loads display names from the custom hats config", %{config_path: config_path} do
    assert CustomHatsConfig.names(config_path) == %{
             "mercenary_derby" => "Mercenary Derby",
             "punishing_bird" => "Punishing Bird",
             "single_hat" => "Only One User"
           }
  end

  test "counts hats equipped by more than one player", context do
    assert CustomHatPopularity.list(
             clientprefs_path: context.database_path,
             custom_hats_path: context.config_path
           ) == [
             %{
               hat_id: "punishing_bird",
               name: "Punishing Bird",
               equipped_clients: 4
             },
             %{
               hat_id: "mercenary_derby",
               name: "Mercenary Derby",
               equipped_clients: 3
             }
           ]
  end
end
