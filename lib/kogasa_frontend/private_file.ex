defmodule KogasaFrontend.PrivateFile do
  @moduledoc false

  # Publish a newly created file only AFTER its mode is0600. This avoids a
  # creation/chmod readability window when a configured parent is traversable.
  # Never chmod the caller's existing parent or follow a leaf symlink.
  def ensure(path) do
    File.mkdir_p!(Path.dirname(path))

    case File.lstat(path) do
      {:ok, %File.Stat{type: :regular}} -> File.chmod(path, 0o600)
      {:ok, _} -> {:error, :unsafe_file}
      {:error, :enoent} -> create(path)
      {:error, _} = error -> error
    end
  end

  defp create(path) do
    dir =
      Path.join(Path.dirname(path), ".private-" <> Base.encode16(:crypto.strong_rand_bytes(16)))

    file = Path.join(dir, "file")

    with :ok <- File.mkdir(dir) do
      try do
        with :ok <- File.chmod(dir, 0o700),
             :ok <- File.write(file, ""),
             :ok <- File.chmod(file, 0o600) do
          case File.ln(file, path) do
            :ok -> :ok
            {:error, :eexist} -> ensure(path)
            {:error, _} = error -> error
          end
        end
      after
        File.rm(file)
        File.rmdir(dir)
      end
    end
  end
end
