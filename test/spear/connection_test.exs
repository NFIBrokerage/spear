defmodule Spear.ConnectionTest do
  use ExUnit.Case

  test "attempting to start a connection to a server that doesn't exist fails" do
    params = [connection_string: "esdb://localhost:54325"]

    assert {:error, _reason} = start_supervised({Spear.Connection, params})
  end

  test "a connection can noop random info messages" do
    conn = start_supervised!({Spear.Connection, connection_string: "esdb://localhost:2113"})

    send(conn, :crypto.strong_rand_bytes(16))

    refute_receive _
  end
end
