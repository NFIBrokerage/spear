defmodule Spear.UuidTest do
  use ExUnit.Case, async: true

  alias Spear.Uuid

  test "we can reproduce a UUID from two 64-bit integers" do
    assert Uuid.from_structured(-1_466_833_724_069_688_543, -8_694_761_462_116_790_879) ==
             "eba4c27f-e443-4b21-8756-00845bc5cda1"
  end
end
