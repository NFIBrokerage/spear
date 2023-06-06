defmodule Spear.Event do
  @moduledoc """
  A simplified event struct

  This event struct is easier to work with than the protobuf definitions for
  AppendReq and ReadResp records
  """

  require Spear.Records.Streams, as: Streams
  require Spear.Records.Persistent, as: Persistent
  require Spear.Records.Shared, as: Shared

  defstruct [:id, :type, :body, :link, metadata: %{}]

  @typedoc """
  A struct representing an EventStoreDB event

  `t:Spear.Event.t/0`s may be created to write to the EventStoreDB with
  `new/3`. `t:Spear.Event.t/0`s will be lazily mapped into
  gRPC-compatible structs before being written to the EventStoreDB with
  `to_proposed_message/2`.

  `t:Spear.Event.t/0`s typically look different between events which are
  written to- and events which are read from the EventStoreDB. Read events
  contain more metadata which pertains to EventStoreDB specifics like
  the creation timestamp of the event.

  ## Links

  The `:link` field of a `t:Spear.Event.t/0` can contain another
  `t:Spear.Event.t/0` struct. Link events are pointers to other events and are
  used by the EventStoreDB to provide the projections feature without having
  to duplicate events across streams. Links do not usually contain any
  information useful to consumers, but clients must keep track of links in
  order to keep an accurate position in a projected stream, or in order to
  `Spear.ack/3`/`Spear.nack/4` the projected events in a persistent
  subscription.

  The `:from` option in functions like `Spear.read_stream/3`, `Spear.stream!/3`
  or `Spear.subscribe/4` will use the link event's `.metadata.stream_revision`
  when reading projected streams. `Spear.ack/3` and `Spear.nack/4` take
  the link's `:id` field when passed a `t:Spear.Event.t/0`. When not passing
  `t:Spear.Event.t/0`s (for example, if curating the stream revisions or IDs
  in a database), the `revision/1` and `id/1` functions may be used to return
  the proper metadata for standard subscriptions and persistent subscriptions,
  respectively.

  ## Examples

      iex> Spear.stream!(conn, "es_supported_clients") |> Enum.take(1)
      [
        %Spear.Event{
          body: %{"languages" => ["typescript", "javascript"], "runtime" => "NodeJS"},
          id: "1fc908c1-af32-4d06-a9bd-3bf86a833fdf",
          metadata: %{
            commit_position: 18446744073709551615,
            content_type: "application/json",
            created: ~U[2021-04-01 21:11:38.196799Z],
            custom_metadata: "",
            prepare_position: 18446744073709551615,
            stream_name: "es_supported_clients",
            stream_revision: 0
          },
          type: "grpc-client",
          link: nil
        }
      ]
      iex> Spear.Event.new("grpc-client", %{"languages" => ["typescript", "javascript"], "runtime" => "NodeJS"},
      %Spear.Event{
        body: %{"languages" => ["typescript", "javascript"], "runtime" => "NodeJS"},
        id: "b952575a-1014-404d-ba20-f0904df7954e",
        metadata: %{content_type: "application/json", custom_metadata: ""},
        type: "grpc-client",
        link: nil
      }
  """
  @typedoc since: "0.1.0"
  @type t :: %__MODULE__{
          id: String.t(),
          type: String.t(),
          body: term(),
          link: t() | nil,
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
    `"application/json"`, the EventStoreDB and Spear (in
    `Spear.Event.from_read_response/2`)
  * `:custom_metadata` - (default: `""`) an event field outside the body
    meant as a bag for storing custom attributes about an event. Usage of this
    field is not obligatory: leaving it blank is perfectly normal.

  ## Event IDs

  EventStoreDB uses event IDs to provide an idempotency feature. Any event
  written to the EventStoreDB with an already existing ID will be not be
  duplicated.

  ```elixir
  iex> event = Spear.Event.new("grpc-client", %{"languages" => ["typescript", "javascript"], "runtime" => "NodeJS"})
  %Spear.Event{
    body: %{"languages" => ["typescript", "javascript"], "runtime" => "NodeJS"},
    id: "1e654b2a-ff04-4af8-887f-052442edcd83",
    metadata: %{content_type: "application/json", custom_metadata: ""},
    type: "grpc-client"
  }
  iex> [event] |> Spear.append(conn, "idempotency_test")
  :ok
  iex> [event] |> Spear.append(conn, "idempotency_test")
  :ok
  iex> Spear.stream!(conn, "idempotency_test") |> Enum.to_list()
  [
    %Spear.Event{
      body: %{"languages" => ["typescript", "javascript"], "runtime" => "NodeJS"},
      id: "1e654b2a-ff04-4af8-887f-052442edcd83",
      metadata: %{
        commit_position: 18446744073709551615,
        content_type: "application/json",
        created: ~U[2021-04-07 21:53:40.395681Z],
        custom_metadata: "",
        prepare_position: 18446744073709551615,
        stream_name: "idempotency_test",
        stream_revision: 0
      },
      type: "grpc-client"
    }
  ]
  ```

  ## Event Store DB Event Metadata

  All names starting with $ are reserved space for internal use, the most commonly used are the following:

  - `$correlationId`:	The application level correlation ID associated with this message.
  - `$causationId`:	The application level causation ID associated with this message.

  In order to use these fields, you must pass them as custom metadata:

  ```elixir
  iex> custom_metadata =  Jason.encode!(%{"$correlationId" => "...", "$causationId" => "..."})
  ...> Spear.Event.new("my_event", %{"id" => 1}, custom_metadata: custom_metadata)
  %Spear.Event{
    id: "d77c1abc-0200-4804-81cd-eca726911166",
    type: "my_event",
    body: %{"id" => 1},
    link: nil,
    metadata: %{
      content_type: "application/json",
      custom_metadata: "{\"$causationId\":\"...\",\"$correlationId\":\"...\"}"
    }
  }
  ```

  > #### Custom Metadata Format {: .tip}
  >
  > In order to leverage the EventStoreDB System Projections such as `$by_correlation_id` or JS Projections; you must
  > pass the custom metadata as JSON.

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
  @doc since: "0.1.0"
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
  Converts a `Spear.Event` into an append-request record which proposes a new
  message

  Note that each event must be individually structured as an `AppendReq`
  record in order to be written to an EventStoreDB. The RPC definition for
  writing events specifies a stream input, though, so all `AppendReq` events
  passed to `Spear.append/4` will be batched into a single write operation.
  This write operation appears to be transactional: any events in a single
  call to `Spear.append/4` will only be appended if all events can be appended.

  ```protobuf
  rpc Append (stream AppendReq) returns (AppendResp);
  ```

  These messages are serialized to wire data before being sent to the
  EventStoreDB when using `Spear.append/4` to write events via protobuf encoding.

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
      [{:"event_store.client.streams.AppendReq", ..}, ..]
  """
  @doc since: "0.1.0"
  @spec to_proposed_message(t(), encoder_mapping :: %{}, type :: :append | :batch_append) ::
          tuple()
  def to_proposed_message(
        event,
        encoder_mapping \\ %{"application/json" => &Jason.encode!/1},
        # coveralls-ignore-start
        type \\ :append
        # coveralls-ignore-stop
      )

  def to_proposed_message(event, encoder_mapping, :append) do
    encoder = Map.get(encoder_mapping, event.metadata.content_type, & &1)

    Streams.append_req(
      content:
        {:proposed_message,
         Streams.append_req_proposed_message(
           custom_metadata: event.metadata.custom_metadata,
           data: encoder.(event.body),
           id: Shared.uuid(value: {:string, event.id}),
           metadata: %{"content-type" => event.metadata.content_type, "type" => event.type}
         )}
    )
  end

  def to_proposed_message(event, encoder_mapping, :batch_append) do
    encoder = Map.get(encoder_mapping, event.metadata.content_type, & &1)

    Streams.batch_append_req_proposed_message(
      custom_metadata: event.metadata.custom_metadata,
      data: encoder.(event.body),
      id: Shared.uuid(value: {:string, event.id}),
      metadata: %{"content-type" => event.metadata.content_type, "type" => event.type}
    )
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

  Event bodies are commonly written to the EventStoreDB in JSON format as the
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
  ...> |> Stream.map(&Spear.Event.from_read_response(&1, json_decoder: &Poison.decode!/2, keys: :atoms))
  ```

  ## Examples

      Spear.stream!(conn, "es_supported_clients", raw?: true)
      |> Stream.map(&Spear.Event.from_read_response/1)
      |> Enum.to_list()
      # => [%Spear.Event{}, %Spear.Event{}, ..]
  """
  @doc since: "0.1.0"
  @spec from_read_response(tuple(), Keyword.t()) :: t()
  def from_read_response(read_response, opts \\ [])

  def from_read_response({_type, {:event, _event}} = read_response, opts) do
    {force_follow_link?, remaining_opts} = Keyword.pop(opts, :link?, false)

    read_response
    |> destructure_read_response(force_follow_link?)
    |> record_to_map()
    |> from_recorded_event(remaining_opts)
  end

  @doc """
  Converts an event into a checkpoint

  This is useful when storing stream positions in `Spear.subscribe/4`
  subscriptions to the `:all` stream.
  """
  @doc since: "0.1.0"
  @spec to_checkpoint(t()) :: Spear.Filter.Checkpoint.t()
  # coveralls-ignore-start
  def to_checkpoint(%__MODULE__{metadata: metadata}) do
    struct(
      Spear.Filter.Checkpoint,
      Map.take(metadata, ~w[commit_position prepare_position subscription]a)
    )
  end

  # coveralls-ignore-stop

  @doc false
  def from_recorded_event(
        %{
          custom_metadata: custom_metadata,
          commit_position: commit_position,
          id: Shared.uuid() = uuid,
          data: body,
          metadata: metadata,
          prepare_position: prepare_position,
          stream_identifier: Shared.stream_identifier(stream_name: stream_name),
          stream_revision: stream_revision
        },
        opts
      ) do
    # metadata comes in as [{k, v}, ..]
    metadata = Map.new(metadata)
    content_type = Map.get(metadata, "content-type")
    {decoder, remaining_opts} = Keyword.pop(opts, :json_decoder, &Jason.decode!/2)

    maybe_decoded_body =
      if content_type == "application/json" do
        decoder.(body, remaining_opts)
      else
        body
      end

    %__MODULE__{
      id: Spear.Uuid.from_proto(uuid),
      type: Map.get(metadata, "type"),
      body: maybe_decoded_body,
      metadata:
        %{
          content_type: content_type,
          created: Map.get(metadata, "created") |> parse_created_stamp(),
          prepare_position: prepare_position,
          commit_position: commit_position,
          custom_metadata: custom_metadata,
          stream_name: stream_name,
          stream_revision: stream_revision
        }
        |> Map.merge(opts[:metadata] || %{})
    }
  end

  def from_recorded_event({event, link}, opts) do
    resolved_event = from_recorded_event(event, opts)
    link_event = from_recorded_event(link, opts)

    put_in(resolved_event.link, link_event)
  end

  defp destructure_read_response(
         Streams.read_resp(
           content:
             {:event,
              Streams.read_resp_read_event(
                link: :undefined,
                event: Streams.read_resp_read_event_recorded_event() = event
              )}
         ),
         _link?
       ) do
    event
  end

  defp destructure_read_response(
         Persistent.read_resp(
           content:
             {:event,
              Persistent.read_resp_read_event(
                link: :undefined,
                event: Persistent.read_resp_read_event_recorded_event() = event
              )}
         ),
         _link?
       ) do
    event
  end

  defp destructure_read_response(
         Streams.read_resp(
           content:
             {:event,
              Streams.read_resp_read_event(
                event: :undefined,
                link: Streams.read_resp_read_event_recorded_event() = event
              )}
         ),
         _link?
       ) do
    event
  end

  # coveralls-ignore-start
  defp destructure_read_response(
         Persistent.read_resp(
           content:
             {:event,
              Persistent.read_resp_read_event(
                event: :undefined,
                link: Persistent.read_resp_read_event_recorded_event() = event
              )}
         ),
         _link?
       ) do
    event
  end

  # coveralls-ignore-stop

  defp destructure_read_response(
         Streams.read_resp(
           content:
             {:event,
              Streams.read_resp_read_event(
                link: Streams.read_resp_read_event_recorded_event() = event
              )}
         ),
         true = _link?
       ) do
    event
  end

  # coveralls-ignore-start
  defp destructure_read_response(
         Persistent.read_resp(
           content:
             {:event,
              Persistent.read_resp_read_event(
                link: Persistent.read_resp_read_event_recorded_event() = event
              )}
         ),
         true = _link?
       ) do
    event
  end

  # coveralls-ignore-stop

  defp destructure_read_response(
         Streams.read_resp(
           content:
             {:event,
              Streams.read_resp_read_event(
                event: Streams.read_resp_read_event_recorded_event() = event,
                link: Streams.read_resp_read_event_recorded_event() = link
              )}
         ),
         false = _link?
       ) do
    {event, link}
  end

  # coveralls-ignore-start
  defp destructure_read_response(
         Persistent.read_resp(
           content:
             {:event,
              Persistent.read_resp_read_event(
                event: Persistent.read_resp_read_event_recorded_event() = event,
                link: Persistent.read_resp_read_event_recorded_event() = link
              )}
         ),
         false = _link?
       ) do
    {event, link}
  end

  # coveralls-ignore-stop

  defp record_to_map({event, link}) do
    {record_to_map(event), record_to_map(link)}
  end

  defp record_to_map(Streams.read_resp_read_event_recorded_event() = event) do
    Streams.read_resp_read_event_recorded_event(event) |> Map.new()
  end

  defp record_to_map(Persistent.read_resp_read_event_recorded_event() = event) do
    Persistent.read_resp_read_event_recorded_event(event) |> Map.new()
  end

  defp parse_created_stamp(nil), do: nil

  defp parse_created_stamp(stamp) when is_binary(stamp) do
    with {ticks_since_epoch, ""} <- Integer.parse(stamp),
         {:ok, datetime} <- Spear.parse_stamp(ticks_since_epoch) do
      datetime
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
  # heard that laywers generally don't like the term "probably."
  #
  # If a reader has advice on how to properly attribute this, please open an
  # issue :)

  @doc """
  Produces a random UUID v4 in human-readable format

  ## Examples

      iex> Spear.Event.uuid_v4
      "98d3a5e2-ceb4-4a78-8084-97edf9452823"
      iex> Spear.Event.uuid_v4
      "2629ea4b-d165-45c9-8a2f-92b5e20b894e"
  """
  @doc since: "0.1.0"
  @spec uuid_v4() :: binary()
  defdelegate uuid_v4(), to: Spear.Uuid

  @doc """
  Produces a consistent UUID v4 in human-readable format given any input
  data structure

  This function can be used to generate a consistent UUID for a data structure
  of any shape. Under the hood it uses `:erlang.phash2/1` to hash the data
  structure, which should be portable across many environments.

  This function can be taken advantage of to generate consistent event
  IDs for the sake of idempotency (see the Event ID section in `new/3`
  for more information). Pass the `:id` option to `new/3` to override the
  default random UUID generation.

  Note that it this implementation is naive and not easily portable across
  programming languages because of the reliance on `:erlang.phash2/1`.
  A v5 UUID can be used instead to the same effect with more portability,
  however a v5 UUID generator is not included in this library.

  ## Examples

      iex> Spear.Event.uuid_v4 %{"foo" => "bar"}
      "33323639-3934-4339-b332-363939343339"
      iex> Spear.Event.uuid_v4 %{"foo" => "bar"}
      "33323639-3934-4339-b332-363939343339"
  """
  @doc since: "0.1.0"
  defdelegate uuid_v4(term), to: Spear.Uuid

  @doc """
  Returns the revision of the event, following the event's link if provided

  ## Examples

      iex> Spear.Event.revision(%Spear.Event{link: nil, metadata: %{stream_revision: 1, ..}, ..})
      1
      iex> Spear.Event.revision(
      ...>   %Spear.Event{
      ...>     link: %Spear.Event{metadata: %{stream_revision: 1, ..}, ..},
      ...>     metadata: %{stream_revision: 0, ..},
      ...>     ..
      ...>   }
      ...> )
      1
  """
  @doc since: "0.9.0"
  @spec revision(t()) :: non_neg_integer()
  def revision(%__MODULE__{link: %__MODULE__{} = link}), do: revision(link)
  def revision(%__MODULE__{metadata: %{stream_revision: revision}}), do: revision

  @doc """
  Returns the ID of the event, following the event's link if provided

  ## Examples

      iex> Spear.Event.id(%Spear.Event{link: nil, id: "817cf20b-6791-4979-afdd-da4b03e02007", ..)
      "817cf20b-6791-4979-afdd-da4b03e02007"
      iex> Spear.Event.id(
      ...>   %Spear.Event{
      ...>     link: %Spear.Event{id: "976601b0-3775-442e-b98c-5f56af809402", ..},
      ...>     id: "817cf20b-6791-4979-afdd-da4b03e02007",
      ...>     ..
      ...>   }
      ...> )
      "976601b0-3775-442e-b98c-5f56af809402"
  """
  @doc since: "0.9.0"
  @spec id(t()) :: String.t()
  def id(%__MODULE__{link: %__MODULE__{} = link}), do: id(link)
  def id(%__MODULE__{id: id}), do: id

  @doc false
  def event?(Streams.read_resp(content: {:event, _event})), do: true
  def event?(%__MODULE__{}), do: true
  def event?(_), do: false
end
