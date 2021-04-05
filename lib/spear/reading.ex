defmodule Spear.Reading do
  @moduledoc """
  Helper functions for reading streams

  TODO
  """

  alias Spear.Protos.EventStore.Client.{Shared, Streams.ReadReq, Streams.ReadResp}

  @doc false
  def decode_next_message(message) do
    Spear.Grpc.decode_next_message(message, ReadResp)
  end

  @doc """
  Maps each read response element in a struct to the event body

  `#{inspect(ReadResp)}` structures are not the easiest to work with because
  of nested tuples and fields. Unless an author is developing meta-tooling
  on top of this library or checking commit positions, the only really relevant
  data in each `#{inspect(ReadResp)}` structure is the event body, typically
  (but not necessarily) a JSON-encoded `t:String.t/0`.

  This function destructures the `#{inspect(ReadResp)}` structures down to the
  event data. It does not attempt to decode this data, however. A stream
  composed with this function may then compose with `decode_as!/2` in
  order to decode as JSON or as Erlang terms.

  ## Options

  * `:link?` - (default: `false`) whether to read the body of the event link,
    if it exists. If the event does not contain a link, the body of the event
    will be returned instead. See the module documentation for `Spear` for
    more information about links and resolution.

  ## Examples

      iex> Spear.stream!(conn, "$et-grpc-client", chunk_size: 1, resolve_links?: false)
      ...> |> Spear.Reading.decode_to_event_body()
      ...> |> Enum.take(1)
      ["0@es_supported_clients"]
      iex> Spear.stream!(conn, "$et-grpc-client", chunk_size: 1, resolve_links?: true)
      ...> |> Spear.Reading.decode_to_event_body(link?: true)
      ...> |> Enum.take(1)
      ["0@es_supported_clients"]
      iex> Spear.stream!(conn, "$et-grpc-client", chunk_size: 1, resolve_links?: true)
      ...> |> Spear.Reading.decode_to_event_body(link?: false)
      ...> |> Enum.take(1)
      ["{\\"languages\\":[\\"typescript\\",\\"javascript\\"],\\"runtime\\":\\"NodeJS\\"}"]
      iex> Spear.stream!(conn, "es_supported_clients", chunk_size: 1)
      ...> |> Spear.Reading.decode_to_event_body()
      ...> |> Enum.take(1)
      ["{\\"languages\\":[\\"typescript\\",\\"javascript\\"],\\"runtime\\":\\"NodeJS\\"}"]
  """
  def decode_to_event_body(event_stream, opts \\ []) do
    link? = Keyword.get(opts, :link?, false)

    Stream.map(event_stream, &decode_read_response(&1, link?))
  end

  defp decode_read_response(
         %ReadResp{
           content:
             {:event,
              %ReadResp.ReadEvent{link: nil, event: %ReadResp.ReadEvent.RecordedEvent{data: data}}}
         },
         _link?
       ) do
    data
  end

  defp decode_read_response(
         %ReadResp{
           content:
             {:event, %ReadResp.ReadEvent{link: %ReadResp.ReadEvent.RecordedEvent{data: data}}}
         },
         _link? = true
       ) do
    data
  end

  defp decode_read_response(
         %ReadResp{
           content:
             {:event, %ReadResp.ReadEvent{event: %ReadResp.ReadEvent.RecordedEvent{data: data}}}
         },
         _link? = false
       ) do
    data
  end

  @doc """
  Decodes a message body using a 2-arity decoder function.

  This function is allowed to raise error when the event body cannot be decoded
  according to the decoder function.

  `opts` defaults to a decoder function of `Jason.decode!/2`. All remaining
  key-value pains in `opts` are passed to the second argument of the decoder
  function.

  Any 2-arity decoder function is allowed as long as it implements the following
  behaviour:

  ```elixir
  @callback decoder_fn(encoded_value :: binary(), opts :: Keyword.t()) :: decoded_value :: term()
  ```

  Where the returned `term` is any decoded value. (Note that the name
  is flexible: the `:decoder` option expects a 2-arity _anonymous_ function.)

  `event_stream` should be a `t:Enumerable.t/0` returned by reading a stream
  with `Spear.stream!/3` or equivalent. This function assumes that it is
  operating on the data payload of an event as is extracted by
  `decode_to_event_body/2`. Note that the enumerable returned by
  `Spear.stream!/3` applies `decode_to_event_body/2` as a default.

  While it is very common to use JSON-encoding due to the wide availability
  of JSON (de/en)coding libraries in virtually all languages, it is not
  necessarily the only choice. Writing events in Erlang term format is a
  reasonable choice if all services reading the stream are able to decode
  the event bodies. For erlang term format, pass `:erlang.binary_to_term/2`
  as the `:decoder` option.

  ## Examples

      iex> event_stream |> Spear.Reading.decode_as!(key: :atoms) |> Enum.to_list()
      [
        %{languages: ["typescript", "javascript"], runtime: "NodeJS"},
      ]
      iex> event_bodies = [<<131, 104, 2, 100, 0, 2, 111, 107, 100, 0, 4, 110, 105, 99, 101>>]
      iex> event_bodies
      ...> |> Spear.Reading.decode_as!(decoder: &:erlang.binary_to_term/2)
      ...> |> Enum.to_list()
      [{:ok, :nice}]
  """
  @spec decode_as!(Enumerable.t(), Keyword.t()) :: Enumerable.t()
  def decode_as!(event_stream, opts \\ []) do
    {decoder, remaining_opts} = Keyword.pop(opts, :decoder, &Jason.decode!/2)

    Stream.map(event_stream, &decoder.(&1, remaining_opts))
  end

  @doc false
  def build_read_request(request_info) when is_map(request_info) do
    build_read_request(
      request_info.stream,
      request_info.revision,
      request_info.max_count,
      request_info.filter,
      request_info.direction,
      request_info.resolve_links?
    )
  end

  @doc false
  @spec build_read_request(
          stream_name :: String.t(),
          revision :: atom() | integer(),
          max_count :: integer(),
          filter :: :TODO,
          direction :: :forwards | :backwards,
          resolve_links? :: boolean()
        ) :: %ReadReq{}
  def build_read_request(stream_name, revision, max_count, filter, direction, resolve_links?) do
    %ReadReq{
      options: %ReadReq.Options{
        count_option: {:count, max_count},
        filter_option: map_filter(filter),
        read_direction: map_direction(direction),
        resolve_links: resolve_links?,
        stream_option:
          {:stream,
           %ReadReq.Options.StreamOptions{
             revision_option: map_revision(revision),
             stream_identifier: %Shared.StreamIdentifier{
               streamName: stream_name
             }
           }},
        uuid_option: %ReadReq.Options.UUIDOption{
          content: {:string, %Shared.Empty{}}
        }
      }
    }
  end

  defp map_revision(:start), do: {:start, %Shared.Empty{}}
  defp map_revision(n) when is_integer(n), do: {:revision, n}
  defp map_revision(:end), do: {:end, %Shared.Empty{}}

  defp map_filter(nil), do: {:no_filter, %Shared.Empty{}}

  defp map_direction(:forwards), do: :Forwards
  defp map_direction(:backwards), do: :Backwards

  @doc """
  Destructures the revision from a ReadResp structure

  If no link is present in the ReadResp, the `:event`'s stream revision is
  used. If a link is present, though, the stream revision of the link takes
  precedence.

  See the `Spear` moduledoc for more information about link resolution.

  ## Examples

      iex> alias Spear.Protos.EventStore.Client.Streams.ReadResp
      iex> read_response =
      ...> Spear.stream!(connection, "my_projected_stream", chunk_size: 1, resolve_links?: true, through: &(&1))
      ...> |> Stream.drop(1)
      ...> |> Enum.take(1)
      ...> |> List.first()
      %ReadResp{
        content: {:event,
         %ReadResp.ReadEvent{
           event: %ReadResp.ReadEvent.RecordedEvent{
             data: "{\\"languages\\":[\\"typescript\\",\\"javascript\\"],\\"runtime\\":\\"NodeJS\\"}",
             stream_revision: 3
           },
           link: %ReadResp.ReadEvent.RecordedEvent{
             data: "3@es_supported_clients",
             stream_revision: 1
           }
         }}
      }
      iex> Spear.Reading.revision(read_response)
      1
      iex> read_response =
      ...> Spear.stream!(connection, "es_supported_clients", chunk_size: 4, resolve_links?: true, through: &(&1))
      ...> |> Stream.drop(3)
      ...> |> Enum.take(1)
      ...> |> List.first()
      %ReadResp{
        content: {:event,
         %ReadResp.ReadEvent{
           event: %ReadResp.ReadEvent.RecordedEvent{
             data: "{\\"languages\\":[\\"typescript\\",\\"javascript\\"],\\"runtime\\":\\"NodeJS\\"}",
             stream_revision: 3
           },
           link: nil
         }}
      }
      iex> Spear.Reading.revision(read_response)
      3
  """
  @spec revision(ReadResp.t()) :: non_neg_integer()
  def revision(%ReadResp{
        content:
          {:event,
           %ReadResp.ReadEvent{
             link: nil,
             event: %ReadResp.ReadEvent.RecordedEvent{stream_revision: revision}
           }}
      }),
      do: revision

  def revision(%ReadResp{
        content:
          {:event,
           %ReadResp.ReadEvent{link: %ReadResp.ReadEvent.RecordedEvent{stream_revision: revision}}}
      }),
      do: revision
end
