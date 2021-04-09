defmodule Spear.ClientTest do
  use ExUnit.Case

  test "the client can be compiled and started" do
    [{module, _}] =
      ~w(test fixtures client.exs)
      |> Path.join()
      |> Code.compile_file()

    assert {:ok, _pid} = start_supervised(module)
  end
end
