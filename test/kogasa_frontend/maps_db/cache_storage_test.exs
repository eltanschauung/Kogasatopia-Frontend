defmodule KogasaFrontend.MapsDb.CacheStorageTest do
  use ExUnit.Case, async: true

  alias KogasaFrontend.MapsDb.CacheStorage

  setup do
    directory =
      Path.join(System.tmp_dir!(), "cache-storage-#{System.unique_integer([:positive])}")

    File.mkdir_p!(directory)
    on_exit(fn -> File.rm_rf!(directory) end)
    %{path: Path.join(directory, "maps.etf")}
  end

  test "round trips plain data with a private mode and no leftover staging file", %{path: path} do
    entry = %{version: 3, payload: %{rows: [%{name: "synthetic", count: 12}], ok: true}}
    assert :ok = CacheStorage.write(path, entry)
    assert {:ok, ^entry} = CacheStorage.read(path)
    assert <<131, tag, _::binary>> = File.read!(path)
    refute tag == 80
    assert Bitwise.band(File.stat!(path).mode, 0o777) == 0o600
    assert File.ls!(Path.dirname(path)) == ["maps.etf"]
  end

  test "rejects compressed, oversized, deeply nested and executable terms", %{path: path} do
    File.write!(
      path,
      :erlang.term_to_binary(%{rows: List.duplicate("data", 1_000)}, [:compressed])
    )

    assert {:error, :invalid_cache} = CacheStorage.read(path)

    File.write!(path, :binary.copy(<<0>>, 4 * 1024 * 1024 + 1))
    assert {:error, :invalid_cache} = CacheStorage.read(path)

    assert {:error, :cache_too_large} =
             CacheStorage.write(path, %{blob: :binary.copy("x", 4 * 1024 * 1024)})

    nested = Enum.reduce(1..50, "value", fn _, value -> [value] end)
    assert {:error, :invalid_cache} = CacheStorage.write(path, nested)

    for invalid <- [self(), make_ref(), &String.upcase/1, %{__struct__: URI, path: "/"}, [1 | 2]] do
      File.write!(path, :erlang.term_to_binary(invalid))
      assert {:error, :invalid_cache} = CacheStorage.read(path)
      assert {:error, :invalid_cache} = CacheStorage.write(path, invalid)
    end
  end

  test "safe decoding never interns an unknown atom", %{path: path} do
    name = "untrusted_cache_atom_#{System.unique_integer([:positive])}"
    assert_raise ArgumentError, fn -> String.to_existing_atom(name) end
    File.write!(path, <<131, 119, byte_size(name), name::binary>>)
    assert {:error, :invalid_cache} = CacheStorage.read(path)
    assert_raise ArgumentError, fn -> String.to_existing_atom(name) end
  end

  test "rejects leaf symlinks and replaces rather than follows an existing destination", %{
    path: path
  } do
    target = path <> ".target"
    File.write!(target, :erlang.term_to_binary(%{keep: "unchanged"}))
    File.ln_s!(target, path)
    assert {:error, :invalid_cache} = CacheStorage.read(path)
    assert :ok = CacheStorage.write(path, %{new: true})
    assert {:ok, %{new: true}} = CacheStorage.read(path)
    assert File.read!(target) == :erlang.term_to_binary(%{keep: "unchanged"})
  end
end
