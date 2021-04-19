defmodule Spear.Uuid do
  @moduledoc false

  import Bitwise,
    only: [
      >>>: 2,
      <<<: 2,
      |||: 2,
      &&&: 2
    ]

  import Spear.Records.Shared, only: [uuid: 1, uuid_structured: 1]

  def from_proto(uuid(value: {:string, uuid})), do: uuid

  def from_proto(
        uuid(
          value:
            {:structured,
             uuid_structured(
               most_significant_bits: most_sig_bits,
               least_significant_bits: least_sig_bits
             )}
        )
      ),
      do: from_structured(most_sig_bits, least_sig_bits)

  @doc """
  Reproduces a UUID from a pair of most and least-significant bits

  This function is an adaptation of the OpenJDK 8 source for turning
  the `java.util.UUID` into a typical string The java source code is as
  follows:

  ```java
  public String toString() {
      return (digits(mostSigBits >> 32, 8) + "-" +
              digits(mostSigBits >> 16, 4) + "-" +
              digits(mostSigBits, 4) + "-" +
              digits(leastSigBits >> 48, 4) + "-" +
              digits(leastSigBits, 12));
  }

  private static String digits(long val, int digits) {
      long hi = 1L << (digits * 4);
      return Long.toHexString(hi | (val & (hi - 1))).substring(1);
  }
  ```

  ## Examples

      iex> Spear.Uuid.from_structured(-1466833724069688543, -8694761462116790879)
      "eba4c27f-e443-4b21-8756-00845bc5cda1"
  """
  @doc since: "0.5.0"
  @spec from_structured(integer(), integer()) :: String.t()
  def from_structured(most_sig_bits, least_sig_bits) do
    [
      digits(most_sig_bits >>> 32, 8),
      digits(most_sig_bits >>> 16, 4),
      digits(most_sig_bits, 4),
      digits(least_sig_bits >>> 48, 4),
      digits(least_sig_bits, 12)
    ]
    |> Enum.intersperse(?-)
    |> IO.iodata_to_binary()
  end

  defp digits(val, digits) do
    hi = 1 <<< (digits * 4)

    <<_drop_first_byte, rest::binary>> =
      (hi ||| (val &&& hi - 1))
      |> Integer.to_string(16)
      |> String.downcase()

    rest
  end

  # a note about this UUID.v4 generator
  #
  # there are a few Elixir UUID generator projects with the most popular
  # (according to hex.pm being zyro/elixir-uuid (permalink https://github.com/zyro/elixir-uuid/tree/346581c7e89872e0e263e10f079e566cf1fc3a68))
  # which at the time of authoring this library appears to be abandoned
  #
  # that project's current implementation of UUID appears to have been
  # optimized in 2019 with help from `@whatyouhide` (https://github.com/zyro/elixir-uuid/commit/9c3fcd2e3090970fa209750cb2f6e102736f5fed)
  #
  # and that optimization appears to be related to a change to Ecto.UUID
  # by `@michalmuskala` in 2016 (https://github.com/elixir-ecto/ecto/commit/158854e588756092f4cac26fa771e219c95dba06#diff-ea16139510c45e1d438b33818ca96742e2f6ba875ed178d807de0436dc920ca9)
  #
  # it's not exactly clear to me how to license this as it appears duplicated
  # across `ecto` and `zyro/elixir-uuid`, with the origin of the material being
  # `ecto`
  #
  # I'll say "this code is not novel and probably belongs to Ecto" but I've
  # heard that laywers generally don't like the term "probably."
  #
  # If a reader has advice on how to properly attribute this, please open an
  # issue :)

  @doc """
  Produces a random UUID v4 in human-readable format
  """
  @doc since: "0.1.0"
  @spec uuid_v4() :: binary()
  def uuid_v4 do
    16 |> :crypto.strong_rand_bytes() |> uuid_v4()
  end

  @doc """
  Produces a consistent UUID v4 in human-readable format given any input
  data structure
  """
  @doc since: "0.1.0"
  @spec uuid_v4(term()) :: binary()
  def uuid_v4(term)

  def uuid_v4(<<u0::48, _::4, u1::12, _::2, u2::62>>) do
    <<u0::48, 4::4, u1::12, 2::2, u2::62>> |> uuid_to_string
  end

  def uuid_v4(term) do
    String.pad_leading("", 16, term |> :erlang.phash2() |> Integer.to_string())
    |> uuid_v4()
  end

  defp uuid_to_string(<<
         a1::4,
         a2::4,
         a3::4,
         a4::4,
         a5::4,
         a6::4,
         a7::4,
         a8::4,
         b1::4,
         b2::4,
         b3::4,
         b4::4,
         c1::4,
         c2::4,
         c3::4,
         c4::4,
         d1::4,
         d2::4,
         d3::4,
         d4::4,
         e1::4,
         e2::4,
         e3::4,
         e4::4,
         e5::4,
         e6::4,
         e7::4,
         e8::4,
         e9::4,
         e10::4,
         e11::4,
         e12::4
       >>) do
    <<e(a1), e(a2), e(a3), e(a4), e(a5), e(a6), e(a7), e(a8), ?-, e(b1), e(b2), e(b3), e(b4), ?-,
      e(c1), e(c2), e(c3), e(c4), ?-, e(d1), e(d2), e(d3), e(d4), ?-, e(e1), e(e2), e(e3), e(e4),
      e(e5), e(e6), e(e7), e(e8), e(e9), e(e10), e(e11), e(e12)>>
  end

  @compile {:inline, e: 1}

  defp e(0), do: ?0
  defp e(1), do: ?1
  defp e(2), do: ?2
  defp e(3), do: ?3
  defp e(4), do: ?4
  defp e(5), do: ?5
  defp e(6), do: ?6
  defp e(7), do: ?7
  defp e(8), do: ?8
  defp e(9), do: ?9
  defp e(10), do: ?a
  defp e(11), do: ?b
  defp e(12), do: ?c
  defp e(13), do: ?d
  defp e(14), do: ?e
  defp e(15), do: ?f
end
