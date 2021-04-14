defmodule Spear.ConnectionTest do
  use ExUnit.Case

  import ExUnit.CaptureLog

  describe "given a connection_string leading nowhere" do
    setup do
      [connection_string: "esdb://localhost:54325"]
    end

    test "a connection will start but fail ping checks", c do
      assert {:ok, conn} =
               start_supervised({Spear.Connection, connection_string: c.connection_string})

      assert Spear.ping(conn) == {:error, :closed}
      assert Spear.ping(conn) == {:error, :closed}
      assert Spear.ping(conn) == {:error, :closed}
    end
  end

  describe "given invalid params" do
    setup do
      [params: []]
    end

    test "the connection does an :ignore start-up and logs an error", c do
      log =
        capture_log([level: :error], fn ->
          assert start_supervised({Spear.Connection, c.params}) == {:ok, :undefined}
        end)

      assert log =~ "Spear.Connection"
      assert log =~ "did not find enough information"
    end
  end

  test "a connection can be told to disconnect and connect" do
    conn = start_supervised!({Spear.Connection, connection_string: "esdb://localhost:2113"})

    assert Connection.call(conn, :close) == {:ok, :closed}
    assert Process.alive?(conn)
    assert Spear.ping(conn) == {:error, :closed}
    assert Connection.cast(conn, :connect) == :ok
    assert Spear.ping(conn) == :pong
  end

  test "a connection can noop random info messages" do
    conn = start_supervised!({Spear.Connection, connection_string: "esdb://localhost:2113"})

    send(conn, :crypto.strong_rand_bytes(16))

    refute_receive _
  end
end
