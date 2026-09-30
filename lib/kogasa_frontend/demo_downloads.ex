defmodule KogasaFrontend.DemoDownloads do
  @moduledoc """
  Links only to readable recordings already published in the FastDL directory.
  FastDL serves this same filesystem, so no per-log HTTP probes are needed.
  """

  alias KogasaFrontend.FastdlSite

  def directory do
    Application.get_env(
      :kogasa_frontend,
      :demo_directory,
      Path.join(FastdlSite.docroot(), "demos")
    )
  end

  def url(filename, directory \\ directory())

  def url(filename, directory) when is_binary(filename) do
    if Regex.match?(~r/\A[A-Za-z0-9_-]+\.dem\z/, filename) do
      path = Path.join(directory, filename)

      with {:ok, %{type: :regular, size: size}} when size > 1072 <- File.lstat(path),
           {:ok, :ok} <- File.open(path, [:read, :binary], fn _file -> :ok end) do
        "https://fastdl.kogasa.tf/demos/" <> URI.encode(filename)
      else
        _ -> nil
      end
    end
  end

  def url(_filename, _directory), do: nil
end
