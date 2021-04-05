defmodule Spear.Event do
  @moduledoc """
  A simplified event struct

  This event struct is easier to work with than the protobuf definitions for
  AppendReq and ReadResp structs
  """

  alias Spear.Protos.EventStore.Client.{Shared, Streams.AppendReq, Streams.ReadResp}

  defstruct [:id, :type, :body, metadata: %{}]

  @type t :: %__MODULE__{
          id: String.t(),
          type: String.t(),
          body: term(),
          metadata: map()
        }

  @doc """
  Creates an event struct

  This function does not append the event to a stream on its own, but can
  provide events to `Spear.append/4` which will append events to a stream.

  `type` is any string used to declare how the event is typed. This is very
  arbitrary and may coincide with struct names or may be hard-coded per event.

  ## Options

  * `:id` - (default: `Spear.Event.uuid_v4()`) the event's ID. See the section
    on event IDs below.
  * `:content_type` - (default: `"application/json"`) the encoding used to
    turn the event's body into binary data. If the content-type is
    `"application/json"`, the EventStore and Spear (in
    `Spear.Event.from_read_response/2`)
  * `:custom_metadata` - (default: `""`) an event field outside of the body
    meant as a bag for storing custom attributes about an event. Usage of this
    field is not obligatory: leaving it blank is perfectly normal.

  ## Event IDs

  EventStore uses event IDs to provide an idempotency feature. Any event
  written to the EventStore

  TODO

  ## Examples

      File.stream!("data.csv")
      |> MyCsvParser.parse_stream()
      |> Stream.map(fn [id, type, amount] ->
        Spear.Event.new("ChargeDeclared",
          %{id: id, type: type, amount: amount}
        )
      end)
      |> Spear.append(conn, "ChargesFromCsvs", batch_size: 20)
  """
  @spec new(String.t(), term(), Keyword.t()) :: t()
  def new(type, body, opts \\ []) when is_binary(type) do
    %__MODULE__{
      body: body,
      type: type,
      id: Keyword.get(opts, :id, uuid_v4()),
      metadata: %{
        content_type: Keyword.get(opts, :content_type, "application/json"),
        custom_metadata: Keyword.get(opts, :custom_metadata, <<>>)
      }
    }
  end

  @doc """
  Converts a `Spear.Event` into an append-request struct which proposes a new
  message

  Note that each event must be individually structured as an `AppendReq`
  message in order to be written to an EventStore. The RPC definition for
  writing events specifies a stream input, though, so all `AppendReq` events
  passed to `Spear.append/4` will be batched into a single write operation.

  ```protobuf
  rpc Append (stream AppendReq) returns (AppendResp);
  ```

  These messages are serialized to wire data before being sent to the
  EventStore when using `Spear.append/4` to write events via protobuf encoding.

  `encoder_mapping` is a mapping of content-types to 1-arity encode functions.
  The default is

  ```elixir
  %{"application/json" => &Jason.encode!/1}
  ```

  The `t:Spear.Event.t/0`'s `.metadata.content_type` value will be searched
  in this map. If an encoder is found for that content-type, the event body
  will be encoded with the encoding function. If no encoder is found, the
  event body will be passed as-is.

  To set up an encoder for something like Erlang term format, an encoding
  map like the following could be used

  ```elixir
  %{"application/vnd.erlang-term-format" => &:erlang.term_to_binary/1}
  ```

  In order to disable JSON encoding, pass an empty map `%{}` as the
  `encoder_mapping`

  ## Examples

      iex> events
      [%Spear.Event{}, %Spear.Event{}, ..]
      iex> events |> Enum.map(&Spear.Event.to_proposed_message/1)
      [%EventStore.Client.Streams.AppendReq{}, ..]
  """
  @spec to_proposed_message(t(), encoder_mapping :: %{}) :: AppendReq.t()
  def to_proposed_message(
        %__MODULE__{} = event,
        encoder_mapping \\ %{"application/json" => &Jason.encode!/1}
      ) do
    encoder = Map.get(encoder_mapping, event.metadata.content_type, & &1)

    %AppendReq{
      content:
        {:proposed_message,
         %AppendReq.ProposedMessage{
           custom_metadata: event.metadata.custom_metadata,
           data: encoder.(event.body),
           id: %Shared.UUID{value: {:string, event.id}},
           metadata: %{
             "content-type" => event.metadata.content_type,
             "type" => event.type
           }
         }}
    }
  end

  @doc """
  Converts a read-response message to a `Spear.Event`

  This function is applied by `Stream.map/2` onto streams returned by
  reading operations such as `Spear.stream!/3`, `Spear.read_stream/3`, etc.
  by default. This can be turned off by passing the `raw?: true` opt to
  a reading function.

  This function follows links. For example, if an read event belongs to a
  projected stream such as an event type stream, this function will give the
  event body of the source event, not the link. Forcing the return of the
  link body can be accomplished with the `:link?` option set to `true` (it is
  `false` by default).

  ## Options

  * `:link?` - (default: `false`) forces returning the body of the link event
    for events read from projected streams. Has no effect on events from non-
    projected streams.
  * `:json_decoder` - (default: `Jason.decode!/2`) a 2-arity function to use
    for events with a `"content-type"` of `"application/json"`.

  All remaining options passed as `opts` other than `:link?` and
  `:json_decoder` are passed to the second argument of the `:json_decoder`
  2-arity function.

  ## JSON decoding

  Event bodies are commonly written to the EventStore in JSON format as the
  format is a human-readable and supported in nearly any language. Events
  carry a small piece of metadata in the `ReadResp.ReadEvent.RecordedEvent`'s
  `:metadata` map field which declares the content-type of the event body:
  `"content-type"`. This function will automatically attempt to decode any
  events which declare an `"application/json"` content-type as JSON using
  the `:json_decoder` 2-arity function option. Other content-types will not
  trigger any automatic behavior.

  `Spear` takes an optional dependency on the `Jason` library as it is
  currently the most popular JSON (en/de)coding library. If you add this
  project to the `deps/0` in a `mix.exs` file and wish to take advantage of
  the automatic JSON decoding functionality, you may also need to include
  `:jason`. As an optional dependency, `:jason` is not included in your
  dependencies just by dependending on `:spear`.

  ```elixir
  # mix.exs
  def deps do
    [
      {:spear, ">= 0.0.0"},
      {:jason, ">= 0.0.0"},
      ..
    ]
  end
  ```

  Other JSON (en/de)coding libraries may be swapped in, such as with `Poison`

  ```elixir
  iex> Spear.stream!(conn, "es_supported_clients", raw?: true)
  ...> |> Stream.map(&Spear.Event.from_read_response(&1, decoder: &Poison.decode!/2, keys: :atoms))

  ## Examples

      Spear.stream!(conn, "es_supported_clients", raw?: true)
      |> Stream.map(&Spear.Event.from_read_response/1)
      |> Enum.to_list()
      # => [%Spear.Event{}, %Spear.Event{}, ..]
  ```
  """
  @spec from_read_response(ReadResp.t(), Keyword.t()) :: t()
  def from_read_response(read_response, opts \\ []) do
    {force_follow_link?, remaining_opts} = Keyword.pop(opts, :link?, false)

    read_response
    |> destructure_read_response(force_follow_link?)
    |> from_recorded_event(remaining_opts)
  end

  @doc false
  def from_recorded_event(
        %ReadResp.ReadEvent.RecordedEvent{
          custom_metadata: custom_metadata,
          commit_position: commit_position,
          id: %Shared.UUID{value: {:string, id}},
          data: body,
          metadata: metadata,
          prepare_position: prepare_position,
          stream_identifier: %Shared.StreamIdentifier{streamName: stream_name},
          stream_revision: stream_revision
        },
        opts
      ) do
    content_type = Map.get(metadata, "content-type")
    {decoder, remaining_opts} = Keyword.pop(opts, :json_decoder, &Jason.decode!/2)

    maybe_decoded_body =
      if content_type == "application/json" do
        decoder.(body, remaining_opts)
      else
        body
      end

    %__MODULE__{
      id: id,
      type: Map.get(metadata, "type"),
      body: maybe_decoded_body,
      metadata: %{
        content_type: content_type,
        created: Map.get(metadata, "created") |> parse_created_stamp(),
        prepare_position: prepare_position,
        commit_position: commit_position,
        custom_metadata: custom_metadata,
        stream_name: stream_name,
        stream_revision: stream_revision
      }
    }
  end

  defp destructure_read_response(
         %ReadResp{content: {:event, %ReadResp.ReadEvent{link: nil, event: event}}},
         _link?
       ) do
    event
  end

  defp destructure_read_response(
         %ReadResp{content: {:event, %ReadResp.ReadEvent{event: nil, link: event}}},
         _link?
       ) do
    event
  end

  defp destructure_read_response(
         %ReadResp{content: {:event, %ReadResp.ReadEvent{link: event}}},
         _link? = true
       ) do
    event
  end

  defp destructure_read_response(
         %ReadResp{content: {:event, %ReadResp.ReadEvent{event: event}}},
         _link? = false
       ) do
    event
  end

  defp parse_created_stamp(nil), do: nil

  defp parse_created_stamp(stamp) when is_binary(stamp) do
    significant_size = byte_size(stamp) - 1

    with <<with_last_byte_cut::binary-size(significant_size), _::binary>> <- stamp,
         {unix_stamp, <<>>} <- Integer.parse(with_last_byte_cut),
         {:ok, parsed} <- DateTime.from_unix(unix_stamp, :microsecond) do
      parsed
    else
      _ -> nil
    end
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
  # heard that laywers generally don't like the term "probably"
  #
  # If a reader has advice on how to properly attribute this, please open an
  # issue :)

  @doc """
  Produces a binary UUID v4 in human-readable format

  ## Examples

      iex> Spear.Writing.uuid_v4
      "98d3a5e2-ceb4-4a78-8084-97edf9452823"
  """
  @spec uuid_v4() :: binary()
  def uuid_v4 do
    <<u0::48, _::4, u1::12, _::2, u2::62>> = :crypto.strong_rand_bytes(16)

    <<u0::48, 4::4, u1::12, 2::2, u2::62>> |> uuid_to_string
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
