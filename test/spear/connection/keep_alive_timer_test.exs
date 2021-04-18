defmodule Spear.Connection.KeepAliveTimerTest do
  use ExUnit.Case, async: true

  alias Spear.Connection.Configuration, as: Config
  alias Spear.Connection.KeepAliveTimer

  test "a connection configured to disable keep-alive sets no timers" do
    timer =
      [connection_string: "esdb://localhost:2113?keepAliveInterval=-1"]
      |> Config.new()
      |> KeepAliveTimer.start()

    assert timer.interval_timer == nil
    assert timer.timeout_timers == %{}
  end

  test "starting a timeout timer inserts the timer into timout_timers" do
    ref = make_ref()

    timer = %KeepAliveTimer{interval: 20, timeout: 10} |> KeepAliveTimer.start_timeout_timer(ref)

    assert_receive :keep_alive_expired

    assert Map.has_key?(timer.timeout_timers, ref)
  end

  test "canceling a timeout timer takes the timer out of timout_timers" do
    ref = make_ref()

    timer =
      %KeepAliveTimer{interval: 300, timeout: 200} |> KeepAliveTimer.start_timeout_timer(ref)

    assert Map.has_key?(timer.timeout_timers, ref)

    timer = KeepAliveTimer.clear_after_timer(timer, ref)

    refute Map.has_key?(timer.timeout_timers, ref)

    refute_receive :keep_alive_expired
  end
end
