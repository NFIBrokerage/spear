defmodule Spear.EventTest do
  use ExUnit.Case, async: true

  test "a datastructure can produce a seemingly valid UUIDv4" do
    assert Spear.Event.uuid_v4(%{"foo" => "bar"}) == "33323639-3934-4339-b332-363939343339"
  end
end
