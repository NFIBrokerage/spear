defmodule Spear.Connection.KeepAliveTimer do
  @moduledoc false

  # a struct & functions for curating the keep-alive timer

  # gRPC keep-alive is just HTTP2 keep-alive: send PING frames every interval
  # and wait at most timeout before saying the connection is caput

  alias Spear.Connection.Configuration, as: Config

  defstruct interval_timer: nil, expire_after: 10_000, after_timers: %{}

  def start(%Config{keep_alive_interval: interval, keep_alive_timeout: timeout})
      when interval == -1 or timeout == -1,
      do: %__MODULE__{}

  def start(%Config{keep_alive_interval: interval, keep_alive_timeout: timeout}) do
    {:ok, interval_timer} = :timer.send_interval(interval, :keep_alive)

    %__MODULE__{interval_timer: interval_timer, expire_after: timeout}
  end

  def clear(%__MODULE__{interval_timer: interval_timer, after_timers: after_timers}) do
    if match?({:interval, ref} when is_reference(ref), interval_timer) do
      :timer.cancel(interval_timer)
    end

    :ok = Enum.each(after_timers, fn {_request_ref, timer} -> :timer.cancel(timer) end)

    %__MODULE__{}
  end

  def start_after_timer(%__MODULE__{} = keep_alive_timer, request_ref) do
    {:ok, expire_timer} = :timer.send_after(keep_alive_timer.expire_after, :keep_alive_expired)

    put_in(keep_alive_timer.after_timers[request_ref], expire_timer)
  end

  def clear_after_timer(%__MODULE__{} = keep_alive_timer, request_ref) do
    {expire_timer, keep_alive_timer} = pop_in(keep_alive_timer.after_timers[request_ref])

    :timer.cancel(expire_timer)

    keep_alive_timer
  end
end
