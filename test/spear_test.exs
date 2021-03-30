defmodule SpearTest do
  use ExUnit.Case
  doctest Spear

  test "greets the world" do
    assert Spear.hello() == :world
  end
end
