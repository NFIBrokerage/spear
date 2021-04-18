defmodule Spear.Connection.ConfigurationTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias Spear.Connection.Configuration, as: Config

  test "a minimal connection string produces valid config" do
    config = Config.new(connection_string: "esdb://localhost:2113")
    assert config.valid? == true
    assert config.tls? == false
    assert config.scheme == :http

    assert config.keep_alive_interval == 10_000
    assert config.keep_alive_timeout == 10_000
  end

  test "a tls connection string passes validation" do
    config =
      Config.new(
        connection_string:
          "esdb://admin:changeit@localhost:2113?tls=true&keepAliveInterval=30000&keepAliveTimeout=15000"
      )

    assert config.valid? == true
    assert config.tls? == true
    assert config.scheme == :https
    assert config.username == "admin"
    assert config.password == "changeit"
  end

  test "keep-alive interval/timeout can be disabled with -1" do
    config =
      Config.new(
        connection_string:
          "esdb://localhost:2113?tls=true&keepAliveInterval=-1&keepAliveTimeout=-1"
      )

    assert config.valid? == true
    assert config.keep_alive_interval == false
    assert config.keep_alive_interval == false
  end

  test "small keep-alive times emit warning log messages" do
    log =
      capture_log([level: :warn], fn ->
        config =
          Config.new(
            connection_string:
              "esdb://localhost:2113?tls=true&keepAliveInterval=1000&keepAliveTimeout=1000"
          )

        assert config.valid? == true
        assert config.keep_alive_interval == 1_000
        assert config.keep_alive_timeout == 1_000
      end)

    assert log =~ "keepAliveInterval"
    assert log =~ "keepAliveTimeout"
    assert log =~ "less than recommended 10_000ms"
  end

  test "negative keep-alive values emit errors" do
    config =
      Config.new(
        connection_string:
          "esdb://localhost:2113?tls=true&keepAliveInterval=-500&keepAliveTimeout=-500"
      )

    assert config.valid? == false
    assert [_ | _] = config.errors

    for {key, error_msg} <- config.errors do
      assert key in ~w[keep_alive_interval keep_alive_timeout]a
      assert error_msg =~ "must be greater than 1"
    end
  end

  test "port number 0 gets rejected by validation" do
    config = Config.new(connection_string: "esdb://localhost:0")
    assert config.valid? == false
    assert [{:port, error_msg}] = config.errors
    assert error_msg =~ "0 is not a valid port number"
  end

  test "attempting to override scheme with an invalid value fails validation" do
    config = Config.new(connection_string: "esdb://localhost:2113", scheme: :esdb)
    assert config.valid? == false
    assert [{:scheme, error_msg}] = config.errors
    assert error_msg =~ "scheme :esdb must be :http or :https"
  end

  test "connection params can be entirely crafted without the connection string" do
    config =
      Config.new(
        scheme: :http,
        username: "admin",
        password: "changeit",
        host: "localhost",
        port: 2113
      )

    assert config.valid? == true
  end

  test "mint protocols and mode options cannot be overriden" do
    config =
      Config.new(
        scheme: :http,
        username: "admin",
        password: "changeit",
        host: "localhost",
        port: 2113,
        mint_opts: [protocols: [:http2, :http], mode: :passive]
      )

    assert config.valid? == true
    assert config.mint_opts[:protocols] == [:http2]
    assert config.mint_opts[:mode] == :active
  end
end
