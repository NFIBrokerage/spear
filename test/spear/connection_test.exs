defmodule Spear.ConnectionTest do
  use ExUnit.Case

  import ExUnit.CaptureLog

  @good_config Application.fetch_env!(:spear, :config)

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
      [params: [port: -1]]
    end

    test "the connection does an :ignore start-up and logs an error", c do
      log =
        capture_log([level: :error], fn ->
          assert start_supervised({Spear.Connection, c.params}) == {:ok, :undefined}
        end)

      assert log =~ "Spear.Connection"
      assert log =~ "Invalid configuration passed"
      assert log =~ "port: -1 is not a valid port number"
    end
  end

  test "a connection can be told to disconnect and connect" do
    conn = start_supervised!({Spear.Connection, @good_config})

    assert Connection.call(conn, :close) == {:ok, :closed}
    assert Process.alive?(conn)
    assert Spear.ping(conn) == {:error, :closed}
    assert Connection.cast(conn, :connect) == :ok
    assert Spear.ping(conn) == :pong
  end

  test "a connection can noop random info messages" do
    conn = start_supervised!({Spear.Connection, @good_config})

    send(conn, :crypto.strong_rand_bytes(16))

    refute_receive _, 500
  end

  test "a connection cannot write in read-only mode" do
    config = [{:read_only?, true} | @good_config]
    conn = start_supervised!({Spear.Connection, config})
    assert Spear.append([], conn, "some_stream") == {:error, :read_only}
  end
end
