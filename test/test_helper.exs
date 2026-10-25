ExUnit.start()

if System.get_env("KOGASA_SKIP_TEST_DB") in ["1", "true"] do
  ExUnit.configure(exclude: [database: true])
end

unless System.get_env("KOGASA_SKIP_TEST_DB") in ["1", "true"] do
  Ecto.Adapters.SQL.Sandbox.mode(KogasaFrontend.Repo, :manual)
end
