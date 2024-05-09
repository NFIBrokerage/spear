defmodule Spear.Grpc do
  @moduledoc false

  # gRPC utilities for making requests to the EventStoreDB
  #
  # You could say this little mint-backed client is the "thrust"
  # of the library (hehe).

  def user_agent do
    mint_version =
      case :application.get_key(:mint, :vsn) do
        {:ok, version} ->
          version

        # coveralls-ignore-start
        _ ->
          ~c"0.0.0"
          # coveralls-ignore-stop
      end

    spear_version =
      case :application.get_key(:spear, :vsn) do
        {:ok, version} ->
          version

        # coveralls-ignore-start
        _ ->
          ~c"0.0.0"
          # coveralls-ignore-stop
      end

    "grpc-elixir-spear/#{spear_version} (mint #{mint_version}; Elixir #{System.version()}; OTP #{System.otp_release()})"
  end

  # happy path of parsing DATA frame(s)
  #
  # from the specification (https://github.com/grpc/grpc/blob/fd27fb09b028e5823f3f246e90bad2d02dfd90d3/doc/PROTOCOL-HTTP2.md)
  # format: ABNF
  #
  # begin quote
  #
  # The repeated sequence of Length-Prefixed-Message items is delivered in DATA frames
  #
  # * Length-Prefixed-Message → Compressed-Flag Message-Length Message
  # * Compressed-Flag → 0 / 1 # encoded as 1 byte unsigned integer
  # * Message-Length → {length of Message} # encoded as 4 byte unsigned integer (big endian)
  # * Message → *{binary octet}
  #
  # end quote
  #
  # notes:
  # - "1 byte unsigned integer" is 8 bits, hence `unsigned-integer-8`
  # - `unit(4)` captures 4 bytes for the message_length
  # - endianness does not matter when the binary in question is 1 byte
  #   hence big/little is not specified for `compressed_flag` (however the
  #   default according to the Elixir documentation is big endian).
  #     - it _does_ matter for message_length however which is 4 bytes
  #     - this is why the specification says "big endian" for the message_length
  # - the signature of this function makes it very easy to use with
  #   Stream.unfold/2
  @spec decode_next_message(binary(), {module(), atom()}) :: nil | {tuple(), binary()}
  def decode_next_message(
        <<0::unsigned-integer-8, message_length::unsigned-big-integer-8-unit(4),
          encoded_message::binary-size(message_length), rest::binary>>,
        {module, type}
      ) do
    # YARD decompression
    {module.decode_msg(encoded_message, type), rest}
  end

  def decode_next_message(_empty_or_malformed, {_module, _type}), do: nil
end
