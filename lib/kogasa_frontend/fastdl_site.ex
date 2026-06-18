defmodule KogasaFrontend.FastdlSite do
  @moduledoc false

  @docroot "/var/www/fastdl"
  @hosts MapSet.new([
           "fastdl.kogasa.tf",
           "www.fastdl.kogasa.tf",
           "fastdl.gyate.net",
           "www.fastdl.gyate.net"
         ])

  def docroot, do: @docroot

  def fastdl_host?(host) when is_binary(host) do
    MapSet.member?(@hosts, String.downcase(host))
  end

  def fastdl_host?(_host), do: false

  def safe_resolve(request_path) when is_binary(request_path) do
    rel = request_path |> String.trim_leading("/")
    candidate = Path.expand(rel, @docroot)
    root = Path.expand(@docroot)

    if candidate == root or String.starts_with?(candidate, root <> "/") do
      {:ok, candidate}
    else
      :error
    end
  end
end
