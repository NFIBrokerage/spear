defmodule Spear.Reading.Stream do
  @moduledoc false

  defstruct [
    :connection,
    :stream,
    :from,
    :max_count,
    :direction,
    :filter,
    :resolve_links?,
    :timeout,
    :buffer,
    :credentials
  ]

  @type t :: %__MODULE__{}

  require Spear.Records.Streams, as: Streams
  alias Spear.Reading
  require Spear.Records.Streams, as: Streams

  # matches explicitly on event ReadResps
  defmacrop event do
    quote do
      Spear.Records.Streams.read_resp(content: {:event, _event})
    end
  end

  def new!(opts) do
    opts = Keyword.put(opts, :max_count, opts[:chunk_size])
    state = struct(__MODULE__, opts)
    response = request!(state)

    wrap_buffer_in_decode_stream(
      state,
      response,
      &unfold_continuous/1
    )
  end

  @spec read_chunk(Keyword.t()) :: {:ok, Enumerable.t()} | {:error, any()}
  def read_chunk(opts) do
    struct(__MODULE__, opts)
    |> request(_raw? = false)
  end

  def wrap_buffer_in_decode_stream(state, buffer, unfold_fn) do
    case unfold_chunk(buffer) do
      {Streams.read_resp(content: {:stream_not_found, Streams.read_resp_stream_not_found()}),
       _rest} ->
        []

      {message, _rest} ->
        Stream.unfold(
          %__MODULE__{state | buffer: buffer, from: message},
          unfold_fn
        )

      nil ->
        []
    end
  end

  defp request(state, raw?) do
    read_request = Reading.build_read_request(state)

    Spear.request(state.connection, Streams, :Read, [read_request],
      timeout: state.timeout,
      credentials: state.credentials,
      raw?: raw?
    )
  end

  defp request!(state) do
    {:ok, response} = request(state, _raw? = true)

    response
  end

  @spec unfold_chunk(binary()) :: {struct(), binary()} | nil
  def unfold_chunk(buffer) when is_binary(buffer) do
    Spear.Grpc.decode_next_message(
      buffer,
      {Streams.service_module(), :"event_store.client.streams.ReadResp"}
    )
  end

  # in this case the buffer has run dry and we need to request more events
  # (a new buffer) with a new ReadReq
  @spec unfold_continuous(t()) :: {emitted_element :: tuple(), t()} | nil
  defp unfold_continuous(%__MODULE__{buffer: <<>>, from: from} = state) do
    response = request!(%__MODULE__{state | max_count: state.max_count + 1})

    # discard the first message since it is `from`
    with {^from, <<_head, _::binary>> = rest} <- unfold_chunk(response),
         # look ahead in `rest` to ensure it's an event read response
         {event(), _} <- unfold_chunk(rest) do
      unfold_continuous(%__MODULE__{state | buffer: rest})
    else
      # discard trailing stream position message
      _ ->
        nil
    end
  end

  defp unfold_continuous(%__MODULE__{buffer: buffer} = state) do
    case unfold_chunk(buffer) do
      {event() = message, remaining_buffer} ->
        {message, %__MODULE__{state | buffer: remaining_buffer, from: message}}

      # skip non-event read responses
      # coveralls-ignore-start
      {Streams.read_resp(), remaining_buffer} ->
        unfold_continuous(%__MODULE__{state | buffer: remaining_buffer})

      # coveralls-ignore-stop

      _ ->
        nil
    end
  end
end
