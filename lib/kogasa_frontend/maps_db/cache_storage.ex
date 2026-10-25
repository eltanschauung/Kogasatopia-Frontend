defmodule KogasaFrontend.MapsDb.CacheStorage do
  @moduledoc false

  alias KogasaFrontend.PrivateFile

  # This is a derived cache, not a general term archive. Reject compression before
  # decoding so a small on-disk file cannot expand without a bound in the decoder.
  @max_bytes 4 * 1024 * 1024
  @max_depth 48

  def read(path) do
    with {:ok, %File.Stat{type: :regular, size: size}} when size <= @max_bytes <-
           File.lstat(path),
         {:ok, binary} <- read_bounded(path),
         <<131, tag, _::binary>> when tag != 80 <- binary,
         entry <- :erlang.binary_to_term(binary, [:safe]),
         true <- data_term?(entry, @max_depth) do
      {:ok, entry}
    else
      _ -> {:error, :invalid_cache}
    end
  rescue
    ArgumentError -> {:error, :invalid_cache}
  end

  def write(path, entry) do
    if data_term?(entry, @max_depth) do
      # Plain ETF keeps the read limit meaningful, including after restarts.
      binary = :erlang.term_to_binary(entry)

      if byte_size(binary) <= @max_bytes do
        atomic_write(path, binary)
      else
        {:error, :cache_too_large}
      end
    else
      {:error, :invalid_cache}
    end
  rescue
    File.Error -> {:error, :io_error}
  end

  defp read_bounded(path) do
    File.open(path, [:read, :binary], fn file -> IO.binread(file, @max_bytes + 1) end)
    |> case do
      {:ok, binary} when is_binary(binary) and byte_size(binary) <= @max_bytes -> {:ok, binary}
      _ -> {:error, :invalid_cache}
    end
  end

  defp atomic_write(path, binary) do
    temporary = path <> ".tmp-" <> Base.encode16(:crypto.strong_rand_bytes(16))

    try do
      with :ok <- PrivateFile.ensure(temporary),
           :ok <- File.write(temporary, binary),
           :ok <- File.rename(temporary, path) do
        :ok
      end
    after
      File.rm(temporary)
    end
  end

  defp data_term?(_value, depth) when depth < 0, do: false

  defp data_term?(value, _depth) when is_binary(value) or is_atom(value) or is_number(value),
    do: true

  defp data_term?(value, depth) when is_list(value) do
    list_data?(value, depth - 1)
  end

  defp data_term?(value, depth) when is_map(value) and not is_struct(value) do
    Enum.all?(value, fn {key, item} ->
      data_term?(key, depth - 1) and data_term?(item, depth - 1)
    end)
  end

  defp data_term?(_value, _depth), do: false

  defp list_data?([], _depth), do: true
  defp list_data?([head | tail], depth), do: data_term?(head, depth) and list_data?(tail, depth)
  defp list_data?(_improper_tail, _depth), do: false
end
