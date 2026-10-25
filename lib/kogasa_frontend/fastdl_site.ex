defmodule KogasaFrontend.FastdlSite do
  @moduledoc false

  @docroot "/var/www/fastdl"
  @hosts MapSet.new([
           "fastdl.kogasa.tf",
           "www.fastdl.kogasa.tf",
           "fastdl.gyate.net",
           "www.fastdl.gyate.net"
         ])

  def docroot, do: Application.get_env(:kogasa_frontend, :fastdl_root, @docroot)

  def fastdl_host?(host) when is_binary(host) do
    MapSet.member?(@hosts, String.downcase(host))
  end

  def fastdl_host?(_host), do: false

  def safe_resolve(request_path) when is_binary(request_path) do
    KogasaFrontend.PublicPath.resolve(docroot(), URI.decode(request_path))
  end
end
