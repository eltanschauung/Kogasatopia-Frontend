defmodule KogasaFrontend.WeaponsRootCacheTest do
  use ExUnit.Case, async: true
  alias KogasaFrontend.{WeaponsRootCache, ValveKeyValues}

  setup do
    server = start_supervised!({WeaponsRootCache, name: nil})
    dir = Path.join(System.tmp_dir!(), "weapons-root-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)
    {:ok, server: server, dir: dir, path: Path.join(dir, "weapons.cfg")}
  end

  test "unchanged contents coalesce parsing; same-size/time edits and replacement invalidate",
       ctx do
    parent = self()

    parser = fn bytes ->
      send(parent, :parse)
      ValveKeyValues.parse(bytes)
    end

    opts = [server: ctx.server, parser: parser]
    File.write!(ctx.path, "\"a\" \"1\"")
    mtime = File.stat!(ctx.path).mtime
    tasks = for _ <- 1..12, do: Task.async(fn -> WeaponsRootCache.load(ctx.path, opts) end)
    Enum.each(tasks, fn t -> assert Task.await(t) == [{"a", "1"}] end)
    assert_receive :parse
    refute_receive :parse
    File.write!(ctx.path, "\"a\" \"2\"")
    File.touch!(ctx.path, mtime)
    assert WeaponsRootCache.load(ctx.path, opts) == [{"a", "2"}]
    assert_receive :parse
    File.write!(ctx.path <> ".new", "\"a\" \"3\"")
    File.rename!(ctx.path <> ".new", ctx.path)
    assert WeaponsRootCache.load(ctx.path, opts) == [{"a", "3"}]
    assert_receive :parse
    File.rm!(ctx.path)
    assert WeaponsRootCache.load(ctx.path, opts) == []
    File.write!(ctx.path, "\"a\" \"3\"")
    assert WeaponsRootCache.load(ctx.path, opts) == [{"a", "3"}]
    assert_receive :parse
  end

  test "errors propagate to caller without killing cache and recovery is immediate", ctx do
    File.write!(ctx.path, "bad")

    assert_raise ArgumentError, fn ->
      WeaponsRootCache.load(ctx.path,
        server: ctx.server,
        parser: fn _ -> raise ArgumentError, "fixture" end
      )
    end

    assert Process.alive?(ctx.server)
    File.write!(ctx.path, "\"good\" \"value\"")
    assert WeaponsRootCache.load(ctx.path, server: ctx.server) == [{"good", "value"}]
  end

  test "bounded paths retain only current digest and evicted paths reparse", ctx do
    parent = self()

    parser = fn bytes ->
      send(parent, bytes)
      ValveKeyValues.parse(bytes)
    end

    for i <- 1..9 do
      path = Path.join(ctx.dir, "#{i}.cfg")
      File.write!(path, "\"a\" \"#{i}\"")
      WeaponsRootCache.load(path, server: ctx.server, parser: parser)
      assert_receive _
    end

    assert map_size(:sys.get_state(ctx.server).entries) == 8
    WeaponsRootCache.load(Path.join(ctx.dir, "1.cfg"), server: ctx.server, parser: parser)
    assert_receive "\"a\" \"1\""
  end

  test "supervised restart reparses public content and state contains no panel values", ctx do
    parent = self()

    parser = fn bytes ->
      send(parent, :parse)
      ValveKeyValues.parse(bytes)
    end

    File.write!(ctx.path, "\"Weapons\" { \"public\" \"value\" }")
    expected = [{"Weapons", [{"public", "value"}]}]
    assert WeaponsRootCache.load(ctx.path, server: ctx.server, parser: parser) == expected
    assert_receive :parse
    %{entries: entries} = :sys.get_state(ctx.server)
    assert [{digest, ^expected}] = Map.values(entries)
    assert byte_size(digest) == 32
    :ok = stop_supervised(WeaponsRootCache)
    fresh = start_supervised!({WeaponsRootCache, name: nil})
    assert WeaponsRootCache.load(ctx.path, server: fresh, parser: parser) == expected
    assert_receive :parse
  end
end
