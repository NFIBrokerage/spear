defmodule Spear.ConnectionTest do
  use ExUnit.Case

  import ExUnit.CaptureLog

  @good_config Application.compile_env!(:spear, :config)

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

  test "a connection started with a 0-arity :on_connect fun invokes the fun at each connection" do
    my_pid = self()

    f = fn -> send(my_pid, :fun_invoked) end
    config = [{:on_connect, f} | @good_config]

    conn = start_supervised!({Spear.Connection, config})

    assert_receive(:fun_invoked)
    assert Connection.call(conn, :close) == {:ok, :closed}
    assert Connection.cast(conn, :connect) == :ok
    assert_receive(:fun_invoked)
  end

  test "a connection started with a 0-arity :on_disconnect fun invokes the fun at each disconnection" do
    my_pid = self()

    f = fn -> send(my_pid, :fun_invoked) end
    config = [{:on_disconnect, f} | @good_config]

    conn = start_supervised!({Spear.Connection, config})

    assert Connection.call(conn, :close) == {:ok, :closed}
    assert_receive(:fun_invoked)
    assert Connection.cast(conn, :connect) == :ok
    assert Connection.call(conn, :close) == {:ok, :closed}
    assert_receive(:fun_invoked)
  end

  test "a connection started with a :on_connect MFA invokes it at each connection" do
    defmodule MfaTest do
      def send_me(pid), do: send(pid, :mfa_invoked)
    end

    my_pid = self()

    config = [{:on_connect, {MfaTest, :send_me, [my_pid]}} | @good_config]

    conn = start_supervised!({Spear.Connection, config})

    assert_receive(:mfa_invoked)
    assert Connection.call(conn, :close) == {:ok, :closed}
    assert Connection.cast(conn, :connect) == :ok
    assert_receive(:mfa_invoked)
  end

  test "a connection started with a :on_disconnect MFA invokes it at each disconnection" do
    defmodule MfaTest do
      def send_me(pid), do: send(pid, :mfa_invoked)
    end

    my_pid = self()

    config = [{:on_disconnect, {MfaTest, :send_me, [my_pid]}} | @good_config]

    conn = start_supervised!({Spear.Connection, config})

    assert Connection.call(conn, :close) == {:ok, :closed}
    assert_receive(:mfa_invoked)
    assert Connection.cast(conn, :connect) == :ok
    assert Connection.call(conn, :close) == {:ok, :closed}
    assert_receive(:mfa_invoked)
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

  test "a connection with an incorrect password cannot subscribe to a stream" do
    config =
      update_in(@good_config[:connection_string], &String.replace(&1, "changeit", "foobarbaz"))

    conn = start_supervised!({Spear.Connection, config})
    assert {:error, reason} = Spear.subscribe(conn, self(), :all)
    assert reason.message == "Bad HTTP status code: 401, should be 200"
  end
end
