defmodule Spear.FilterTest do
  use ExUnit.Case, async: true
  doctest Spear.Filter

  import Spear.Filter

  test "combining modifiers raises argument errors" do
    # cannot have s and t together
    assert_raise ArgumentError, fn -> ~f/Agg.A- Agg.B-/st end
    # cannot have p and r together
    assert_raise ArgumentError, fn -> ~f/Agg.A- Agg.B-/pr end
  end

  test "unknown modifiers raise" do
    assert_raise ArgumentError, fn -> ~f/somepattern/hello end
  end
end
