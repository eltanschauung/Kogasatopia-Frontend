import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/whale_chat start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :whale_chat, WhaleChatWeb.Endpoint, server: true
end

ip =
  case System.get_env("PHX_IP", "0.0.0.0") do
    "0.0.0.0" -> {0, 0, 0, 0}
    "::" -> {0, 0, 0, 0, 0, 0, 0, 0}
    _ -> {127, 0, 0, 1}
  end

http_port = String.to_integer(System.get_env("PORT", "80"))

if config_env() == :dev do
  config :whale_chat, WhaleChat.Repo,
    username: System.get_env("WT_DB_USER", "youruserhere"),
    password: System.get_env("WT_DB_PASS", "yourpasswordhere"),
    hostname: System.get_env("WT_DB_HOST", "127.0.0.1"),
    database: System.get_env("WT_DB_NAME", "sourcemod"),
    port: String.to_integer(System.get_env("WT_DB_PORT", "3306"))
end

if config_env() in [:dev, :test] do
  config :whale_chat,
    chat_ip_secret: System.get_env("WT_CHAT_IP_SECRET", "changeme"),
    chat_server_ip: System.get_env("WT_CHAT_SERVER_IP", "127.0.0.1"),
    chat_server_port: String.to_integer(System.get_env("WT_CHAT_SERVER_PORT", "443")),
    steam_api_key: System.get_env("STEAM_API_KEY", "")
end

if config_env() == :prod do
  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []
  pool_size = String.to_integer(System.get_env("POOL_SIZE") || "10")

  if database_url = System.get_env("DATABASE_URL") do
    config :whale_chat, WhaleChat.Repo,
      url: database_url,
      pool_size: pool_size,
      socket_options: maybe_ipv6
  else
    config :whale_chat, WhaleChat.Repo,
      username:
        System.get_env("WT_DB_USER") ||
          raise("set WT_DB_USER or DATABASE_URL in prod"),
      password:
        System.get_env("WT_DB_PASS") ||
          raise("set WT_DB_PASS or DATABASE_URL in prod"),
      hostname: System.get_env("WT_DB_HOST", "127.0.0.1"),
      database: System.get_env("WT_DB_NAME", "sourcemod"),
      port: String.to_integer(System.get_env("WT_DB_PORT", "3306")),
      pool_size: pool_size,
      socket_options: maybe_ipv6
  end

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"

  config :whale_chat, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :whale_chat,
    chat_ip_secret:
      System.get_env("WT_CHAT_IP_SECRET") ||
        raise("environment variable WT_CHAT_IP_SECRET is missing"),
    chat_server_ip: System.get_env("WT_CHAT_SERVER_IP", "127.0.0.1"),
    chat_server_port: String.to_integer(System.get_env("WT_CHAT_SERVER_PORT", "443")),
    steam_api_key: System.get_env("STEAM_API_KEY", "")

  tls_dir = System.get_env("PHX_TLS_DIR")
  https_port = String.to_integer(System.get_env("HTTPS_PORT", "443"))

  tls_path = fn domain, file ->
    Path.join([tls_dir || "", domain, file])
  end

  tls_charlist = fn domain, file ->
    tls_path.(domain, file)
    |> String.to_charlist()
  end

  sni_hosts =
    if is_binary(tls_dir) and tls_dir != "" do
      [
        {~c"kogasa.tf",
         [
           certfile: tls_charlist.("kogasa.tf", "fullchain.pem"),
           keyfile: tls_charlist.("kogasa.tf", "privkey.pem")
         ]},
        {~c"fastdl.kogasa.tf",
         [
           certfile: tls_charlist.("fastdl.kogasa.tf", "fullchain.pem"),
           keyfile: tls_charlist.("fastdl.kogasa.tf", "privkey.pem")
         ]},
        {~c"fastdl.gyate.net",
         [
           certfile: tls_charlist.("fastdl.gyate.net", "fullchain.pem"),
           keyfile: tls_charlist.("fastdl.gyate.net", "privkey.pem")
         ]}
      ]
    else
      []
    end

  endpoint_opts = [
    url: [host: host, port: https_port, scheme: "https"],
    secret_key_base: secret_key_base,
    http: [
      ip: ip,
      port: http_port
    ]
  ]

  endpoint_opts =
    if sni_hosts == [] do
      endpoint_opts
    else
      Keyword.put(endpoint_opts, :https, [
        ip: ip,
        port: https_port,
        cipher_suite: :strong,
        certfile: tls_path.("kogasa.tf", "fullchain.pem"),
        keyfile: tls_path.("kogasa.tf", "privkey.pem"),
        thousand_island_options: [
          transport_options: [
            sni_hosts: sni_hosts
          ]
        ]
      ])
    end

  config :whale_chat, WhaleChatWeb.Endpoint, endpoint_opts

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :whale_chat, WhaleChatWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :whale_chat, WhaleChatWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.
end
