defmodule KogasaFrontend.OnlineSchemaTest do
  use ExUnit.Case, async: true
  alias KogasaFrontend.OnlineSchema

  setup do
    clock = start_supervised!({Agent, fn -> 0 end})
    server = start_supervised!({OnlineSchema, name: nil, clock: fn -> Agent.get(clock, & &1) end})
    {:ok, clock: clock, server: server}
  end

  test "warm hits avoid introspection but always execute the live callback; expiry and reset",
       ctx do
    parent = self()

    query = fn sql, [] ->
      send(parent, {:metadata, sql})
      {:ok, %{rows: [["steamid"], ["kills"]]}}
    end

    callback = fn cols ->
      send(parent, :live)
      {:ok, MapSet.member?(cols, "kills")}
    end

    opts = [server: ctx.server, query: query]
    assert {:ok, true} = OnlineSchema.with_columns("whaletracker_online", callback, opts)
    assert_receive {:metadata, "SHOW COLUMNS FROM whaletracker_online"}
    assert_receive :live
    assert {:ok, true} = OnlineSchema.with_columns("whaletracker_online", callback, opts)
    assert_receive :live
    refute_receive {:metadata, _}
    Agent.update(ctx.clock, fn _ -> 60_000 end)
    assert {:ok, true} = OnlineSchema.with_columns("whaletracker_online", callback, opts)
    assert_receive {:metadata, _}
    OnlineSchema.invalidate("whaletracker_online", ctx.server)
    assert {:ok, true} = OnlineSchema.with_columns("whaletracker_online", callback, opts)
    assert_receive {:metadata, _}
  end

  test "unknown column and missing table re-introspect exactly once, other errors do not", ctx do
    for code <- [1054, 1146, 1205] do
      parent = self()
      OnlineSchema.invalidate("whaletracker_online", ctx.server)

      query = fn _, [] ->
        send(parent, :metadata)
        {:ok, %{rows: [["steamid"]]}}
      end

      callback = fn _ ->
        send(parent, :live)
        {:error, %{mysql: %{code: code}}}
      end

      assert {:error, _} =
               OnlineSchema.with_columns("whaletracker_online", callback,
                 server: ctx.server,
                 query: query
               )

      assert_receive :metadata
      assert_receive :live

      if code in [1054, 1146] do
        assert_receive :metadata
        assert_receive :live
      end

      refute_receive :metadata
      refute_receive :live
    end
  end

  test "failed and empty metadata are not cached; concurrent successful misses coalesce", ctx do
    for result <- [{:error, :offline}, {:ok, %{rows: []}}] do
      assert {:error, _} =
               OnlineSchema.with_columns("whaletracker_servers", fn _ -> flunk() end,
                 server: ctx.server,
                 query: fn _, _ -> result end
               )
    end

    parent = self()

    query = fn _, _ ->
      send(parent, :metadata)
      {:ok, %{rows: [["visible_max"]]}}
    end

    tasks =
      for _ <- 1..12 do
        Task.async(fn ->
          OnlineSchema.with_columns("whaletracker_servers", fn cols -> {:ok, cols} end,
            server: ctx.server,
            query: query
          )
        end)
      end

    Enum.each(tasks, fn task ->
      assert {:ok, cols} = Task.await(task)
      assert MapSet.member?(cols, "visible_max")
    end)

    assert_receive :metadata
    refute_receive :metadata
  end

  test "retry sees changed columns and recovers", ctx do
    parent = self()
    first = fn _, _ -> {:ok, %{rows: [["removed"]]}} end

    assert {:ok, _} =
             OnlineSchema.with_columns("whaletracker_online", &{:ok, &1},
               server: ctx.server,
               query: first
             )

    query = fn _, _ -> {:ok, %{rows: [["added"]]}} end

    callback = fn cols ->
      send(parent, cols)

      if MapSet.member?(cols, "removed"),
        do: {:error, %{mysql: %{code: 1054}}},
        else: {:ok, :fresh}
    end

    assert {:ok, :fresh} =
             OnlineSchema.with_columns("whaletracker_online", callback,
               server: ctx.server,
               query: query
             )

    assert_receive %MapSet{}
    assert_receive %MapSet{}
  end

  test "supervised restart discards metadata and reads the schema again", ctx do
    parent = self()

    query = fn _, _ ->
      send(parent, :introspect)
      {:ok, %{rows: [["steamid"]]}}
    end

    assert {:ok, _} =
             OnlineSchema.with_columns("whaletracker_online", &{:ok, &1},
               server: ctx.server,
               query: query
             )

    assert_receive :introspect
    :ok = stop_supervised(OnlineSchema)
    fresh = start_supervised!({OnlineSchema, name: nil})

    assert {:ok, _} =
             OnlineSchema.with_columns("whaletracker_online", &{:ok, &1},
               server: fresh,
               query: query
             )

    assert_receive :introspect
  end

  test "raised metadata query stays uncached, keeps worker alive and recovers", ctx do
    query = fn _, _ -> raise ArgumentError, "fixture failure" end

    assert {:error, {:schema_query_exception, ArgumentError}} =
             OnlineSchema.with_columns("whaletracker_online", fn _ -> flunk("no columns") end,
               server: ctx.server,
               query: query
             )

    assert Process.alive?(ctx.server)
    assert :sys.get_state(ctx.server).entries == %{}

    assert {:ok, :recovered} =
             OnlineSchema.with_columns("whaletracker_online", fn _ -> {:ok, :recovered} end,
               server: ctx.server,
               query: fn _, _ -> {:ok, %{rows: [["steamid"]]}} end
             )
  end

  test "absent or stopped cache returns an error without exiting the request", ctx do
    callback = fn _ -> flunk("cache unavailable") end
    query = fn _, _ -> flunk("cache unavailable") end

    assert {:error, {:schema_cache_unavailable, _}} =
             OnlineSchema.with_columns("whaletracker_online", callback,
               server: :absent_online_schema_fixture,
               query: query
             )

    :ok = stop_supervised(OnlineSchema)

    assert {:error, {:schema_cache_unavailable, _}} =
             OnlineSchema.with_columns("whaletracker_online", callback,
               server: ctx.server,
               query: query
             )

    assert {:error, {:schema_cache_unavailable, _}} =
             OnlineSchema.invalidate("whaletracker_online", ctx.server)
  end
end
