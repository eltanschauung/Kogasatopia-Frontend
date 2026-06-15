import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :kogasa_frontend, WhaleChat.Repo,
  username: System.get_env("WT_TEST_DB_USER") || System.get_env("WT_DB_USER") || "root",
  password: System.get_env("WT_TEST_DB_PASS") || System.get_env("WT_DB_PASS") || "",
  hostname: System.get_env("WT_TEST_DB_HOST") || System.get_env("WT_DB_HOST") || "localhost",
  database:
    System.get_env("WT_TEST_DB_NAME") ||
      "kogasa_frontend_test#{System.get_env("MIX_TEST_PARTITION")}",
  port:
    String.to_integer(System.get_env("WT_TEST_DB_PORT") || System.get_env("WT_DB_PORT") || "3306"),
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :kogasa_frontend, WhaleChatWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: System.get_env("SECRET_KEY_BASE") || String.duplicate("0", 64),
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true
