ExUnit.start()

unless System.get_env("KOGASA_SKIP_TEST_DB") in ["1", "true"] do
  Ecto.Adapters.SQL.Sandbox.mode(KogasaFrontend.Repo, :manual)
end
