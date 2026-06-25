defmodule KogasaFrontend.MapsDbSecurityTest do
  use ExUnit.Case, async: false

  alias KogasaFrontend.MapsDb

  setup do
    root = Path.join(System.tmp_dir!(), "maps_db_security_#{System.unique_integer([:positive])}")
    maps_dir = Path.join(root, "mapsdb")
    tf_cfg_dir = Path.join(root, "cfg")
    File.mkdir_p!(maps_dir)
    File.mkdir_p!(tf_cfg_dir)

    old_maps_dir = Application.get_env(:kogasa_frontend, :mapsdb_dir)
    old_tf_cfg_dir = Application.get_env(:kogasa_frontend, :mapsdb_tf_cfg_dir)

    Application.put_env(:kogasa_frontend, :mapsdb_dir, maps_dir)
    Application.put_env(:kogasa_frontend, :mapsdb_tf_cfg_dir, tf_cfg_dir)

    on_exit(fn ->
      restore_env(:mapsdb_dir, old_maps_dir)
      restore_env(:mapsdb_tf_cfg_dir, old_tf_cfg_dir)
      File.rm_rf(root)
    end)

    %{maps_dir: maps_dir, tf_cfg_dir: tf_cfg_dir, root: root}
  end

  test "loads mapsdb configs with strict map names", %{maps_dir: maps_dir} do
    File.write!(Path.join(maps_dir, "koth_test.cfg"), "mp_timelimit 30\nmp_winlimit 2\n")

    assert {:ok, %{content: "mp_timelimit 30\nmp_winlimit 2\n"}} =
             MapsDb.load_config_file("koth_test", "mapsdb")

    assert {:error, :invalid_map} = MapsDb.load_config_file("../server", "mapsdb")
  end

  test "one-line mapsdb configs are hidden from the viewer allowlist", %{maps_dir: maps_dir} do
    File.write!(Path.join(maps_dir, "koth_stub.cfg"), "// Auto-generated config for koth_stub\n")

    assert {:error, :not_found} = MapsDb.load_config_file("koth_stub", "mapsdb")
  end

  test "tfcfg source only loads configs exposed by the viewer", %{tf_cfg_dir: tf_cfg_dir} do
    File.write!(Path.join(tf_cfg_dir, "server.cfg"), "hostname test\nmp_timelimit 30\n")
    File.write!(Path.join(tf_cfg_dir, "secret.cfg"), "rcon_password hidden\n")

    assert {:ok, %{content: "hostname test\nmp_timelimit 30\n"}} =
             MapsDb.load_config_file("server", "tfcfg")

    assert {:error, :not_found} = MapsDb.load_config_file("secret", "tfcfg")
  end

  test "unknown config sources are rejected", %{maps_dir: maps_dir} do
    File.write!(Path.join(maps_dir, "koth_test.cfg"), "mp_timelimit 30\n")

    assert {:error, :invalid_source} = MapsDb.load_config_file("koth_test", "unknown")
  end

  test "symlinked configs are not served", %{maps_dir: maps_dir, root: root} do
    target = Path.join(root, "outside.cfg")
    link = Path.join(maps_dir, "linked.cfg")
    File.write!(target, "outside\n")

    case File.ln_s(target, link) do
      :ok -> assert {:error, :not_found} = MapsDb.load_config_file("linked", "mapsdb")
      {:error, _} -> :ok
    end
  end

  defp restore_env(key, nil), do: Application.delete_env(:kogasa_frontend, key)
  defp restore_env(key, value), do: Application.put_env(:kogasa_frontend, key, value)
end
