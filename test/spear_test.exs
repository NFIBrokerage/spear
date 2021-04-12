defmodule SpearTest do
  use ExUnit.Case, async: true

  alias Spear.Protos.EventStore.Client.Streams.ReadResp

  @moduletag :capture_log

  # bytes
  @max_append_bytes 1_048_576
  @checkpoint_after Integer.pow(32, 3)

  setup do
    conn = start_supervised!({Spear.Connection, connection_string: "http://localhost:2113"})

    [
      conn: conn,
      stream_name: random_stream_name()
    ]
  end

  describe "given a stream contains events" do
    setup c do
      :ok =
        random_events()
        |> Stream.take(7)
        |> Spear.append(c.conn, c.stream_name, expect: :empty)
    end

    test "the stream evens may be read in chunks with stream!/3", c do
      events = Spear.stream!(c.conn, c.stream_name, chunk_size: 3)

      assert Enum.count(events) == 7
    end

    test "an empty expectation will fail on an existing stream", c do
      assert {:error, reason} =
               Spear.append([random_event()], c.conn, c.stream_name, expect: :empty)

      # N.B. zero-indexed
      assert reason == %Spear.ExpectationViolation{current: 6, expected: :empty}
    end

    test "an empty expectation will fail on the wrong stream revision", c do
      assert {:error, reason} = Spear.append([random_event()], c.conn, c.stream_name, expect: 3)

      assert reason == %Spear.ExpectationViolation{current: 6, expected: 3}
    end

    test "reading a stream from `0` starts at the _second_ event in the stream", c do
      # `:from` is exclusive, it will start at the event _after_ that revision
      assert %Spear.Event{body: 1} =
               Spear.stream!(c.conn, c.stream_name, from: 0) |> Enum.take(1) |> List.first()
    end

    test "a stream may be streamed backwards", c do
      to_event_numbers = fn events -> Stream.map(events, & &1.body) |> Enum.to_list() end
      expected_event_numbers = Enum.to_list(6..0//-1)

      assert ^expected_event_numbers =
               Spear.stream!(c.conn, c.stream_name, direction: :backwards, from: :end)
               |> then(to_event_numbers)

      # and with read_stream/3
      assert {:ok, events} =
               Spear.read_stream(c.conn, c.stream_name, direction: :backwards, from: :end)

      assert to_event_numbers.(events) == expected_event_numbers
    end

    test "reading the stream raw returns ReadResp structs", c do
      all_expected_type? = &Enum.all?(&1, fn %type{} -> type == ReadResp end)

      assert Spear.stream!(c.conn, c.stream_name, raw?: true) |> all_expected_type?.()

      # and same with read_stream/3
      assert {:ok, events} = Spear.read_stream(c.conn, c.stream_name, raw?: true)
      assert all_expected_type?.(events)
    end

    test "subscribing at the beginning of a stream emits all of the events", c do
      assert {:ok, sub} = Spear.subscribe(c.conn, self(), c.stream_name, from: :start)

      for n <- 0..6//1 do
        assert_receive %Spear.Event{body: ^n}
      end

      :ok = Spear.cancel_subscription(c.conn, sub)
    end

    test "subscribing to the end of the stream emits no events in the stream", c do
      assert {:ok, sub} = Spear.subscribe(c.conn, self(), c.stream_name, from: :end)

      :ok = Spear.cancel_subscription(c.conn, sub)

      refute_receive %Spear.Event{body: _}
    end

    test "a raw subscription will return ReadResp structs", c do
      assert {:ok, sub} = Spear.subscribe(c.conn, self(), c.stream_name, raw?: true)

      for _n <- 0..6//1 do
        assert_receive %ReadResp{}
      end

      :ok = Spear.cancel_subscription(c.conn, sub)
    end

    test "deleting a stream makes it read as an empty list", c do
      assert Spear.delete_stream(c.conn, c.stream_name) == :ok

      assert Spear.stream!(c.conn, c.stream_name) |> Enum.to_list() == []
    end

    test "a deletion request will fail if the expectation mismatches", c do
      assert Spear.delete_stream(c.conn, c.stream_name, expect: :empty) ==
               {:error,
                %Spear.Grpc.Response{
                  data: "",
                  message:
                    "Append failed due to WrongExpectedVersion. Stream: #{c.stream_name}, Expected version: -1, Actual version: ",
                  status: :failed_precondition,
                  status_code: 9
                }}

      assert Spear.delete_stream(c.conn, c.stream_name, expect: 3) ==
               {:error,
                %Spear.Grpc.Response{
                  data: "",
                  message:
                    "Append failed due to WrongExpectedVersion. Stream: #{c.stream_name}, Expected version: 3, Actual version: ",
                  status: :failed_precondition,
                  status_code: 9
                }}
    end

    test "we can read events by passing an event to a `:from` option", c do
      [one, two] = Spear.stream!(c.conn, c.stream_name) |> Enum.take(2)
      assert [^two] = Spear.stream!(c.conn, c.stream_name, from: one) |> Enum.take(1)
    end
  end

  describe "given a subscription to a stream" do
    setup c do
      {:ok, sub} = Spear.subscribe(c.conn, self(), c.stream_name)

      [sub: sub]
    end

    test "appending an event emits a message to the subscription", c do
      # note that we are not matching on ^event
      # because when an event is appended, the EventStore slaps a bunch of
      # metadata on it like timestamp of commit and such
      Spear.append([random_event()], c.conn, c.stream_name)
      assert_receive %Spear.Event{}

      Spear.append([random_event()], c.conn, c.stream_name)
      assert_receive %Spear.Event{}
    end
  end

  describe "given no prior state" do
    test "streaming a non-existing stream results in an empty list", c do
      assert Spear.stream!(c.conn, c.stream_name) |> Enum.to_list() == []
      assert {:ok, events} = Spear.read_stream(c.conn, c.stream_name)
      assert Enum.to_list(events) == []
    end

    test "attempting to append an infinite stream of events fails with a gRPC error", c do
      # why ~10KB events? if we do this with the tiny events from
      # random_event/0 we get the same results but it's much slower and I want
      # to keep this test suite fast
      events =
        Stream.repeatedly(fn ->
          Spear.Event.new("biggish-event", :binary.copy(<<0>>, 10_000),
            content_type: "application/octet-stream"
          )
        end)

      assert {:error, reason} = Spear.append(events, c.conn, c.stream_name)

      assert reason == maximum_append_size_error()
    end

    test "if we try to write a gigantic event, we get a gRPC error", c do
      big_event =
        Spear.Event.new("biggish-event", :binary.copy(<<0>>, @max_append_bytes + 1),
          content_type: "application/octet-stream"
        )

      assert {:error, reason} = Spear.append([big_event], c.conn, c.stream_name)

      assert reason == maximum_append_size_error()
    end

    test "attempting to append to a tombstoned stream gives a gRPC error", c do
      assert Spear.delete_stream(c.conn, c.stream_name, tombstone?: true) == :ok
      assert {:error, reason} = Spear.append([random_event()], c.conn, c.stream_name)

      assert reason == %Spear.Grpc.Response{
               data: "",
               message: "Event stream '#{c.stream_name}' is deleted.",
               status: :failed_precondition,
               status_code: 9
             }
    end

    test "an exists expectation will fail on an empty stream", c do
      assert {:error, reason} =
               Spear.append([random_event()], c.conn, c.stream_name, expect: :exists)

      assert reason == %Spear.ExpectationViolation{current: :empty, expected: :exists}
    end

    test "a subscription to :all will eventually catch a stream pattern", c do
      <<"Spear.Test-", first_four::binary-size(4), _::binary>> = c.stream_name
      prefix = "Spear.Test-" <> first_four

      :ok =
        random_events()
        |> Stream.take(5)
        |> Spear.append(c.conn, c.stream_name, expect: :empty)

      filter = %Spear.Filter{on: :stream_name, by: [prefix], checkpoint_after: @checkpoint_after}

      {:ok, sub} = Spear.subscribe(c.conn, self(), :all, filter: filter)

      assert_receive %Spear.Event{body: 0} = event, 1_000
      assert %Spear.Filter.Checkpoint{} = Spear.Event.to_checkpoint(event)

      for n <- 1..4//1 do
        assert_receive %Spear.Event{body: ^n}
      end

      Spear.cancel_subscription(c.conn, sub)

      # and it works with a regex/binary
      regex = Regex.compile!("^" <> prefix)
      filter = %Spear.Filter{on: :stream_name, by: regex, checkpoint_after: @checkpoint_after}
      {:ok, sub} = Spear.subscribe(c.conn, self(), :all, filter: filter)

      assert_receive %Spear.Event{body: 0}, 1_000

      for n <- 1..4//1 do
        assert_receive %Spear.Event{body: ^n}
      end

      Spear.cancel_subscription(c.conn, sub)
    end

    test "the exclude_system_events/0 filter produces non-system events", c do
      :ok = [random_event()] |> Spear.append(c.conn, c.stream_name)

      filter =
        Spear.Filter.exclude_system_events() |> Spear.Filter.checkpoint_after(@checkpoint_after)

      {:ok, sub} = Spear.subscribe(c.conn, self(), :all, filter: filter)

      assert_receive %Spear.Event{type: type}

      refute match?("$" <> _, type)

      Spear.cancel_subscription(c.conn, sub)
      # note: just showing that this can be done idempotently and return :ok
      assert Spear.cancel_subscription(c.conn, sub) == :ok
    end

    test "a subscription can pick up from where it left off", c do
      filter = %Spear.Filter{on: :stream_name, by: [c.stream_name]}
      type = "pickup-test"

      event = Spear.Event.new(type, 0)
      :ok = Spear.append([event], c.conn, c.stream_name)

      {:ok, sub} = Spear.subscribe(c.conn, self(), :all, filter: filter)

      assert_receive %Spear.Event{body: 0, type: ^type} = first_event

      Spear.cancel_subscription(c.conn, sub)

      next_event = Spear.Event.new(type, 1)
      :ok = Spear.append([next_event], c.conn, c.stream_name)

      {:ok, sub} = Spear.subscribe(c.conn, self(), :all, filter: filter, from: first_event)

      # note: exclusive on the :from
      refute_receive %Spear.Event{body: 0, type: ^type}
      assert_receive %Spear.Event{body: 1, type: ^type}

      Spear.cancel_subscription(c.conn, sub)
    end

    test "a subscription can pick up from a checkpoint", c do
      filter = %Spear.Filter{on: :stream_name, by: [c.stream_name]}
      type = "checkpoint-test"

      event = Spear.Event.new(type, 0)
      :ok = Spear.append([event], c.conn, c.stream_name)

      {:ok, sub} = Spear.subscribe(c.conn, self(), :all, filter: filter)

      assert_receive %Spear.Event{body: 0, type: ^type}
      assert_receive %Spear.Filter.Checkpoint{} = checkpoint

      Spear.cancel_subscription(c.conn, sub)

      next_event = Spear.Event.new(type, 1)
      :ok = Spear.append([next_event], c.conn, c.stream_name)

      {:ok, sub} = Spear.subscribe(c.conn, self(), :all, filter: filter, from: checkpoint)

      assert_receive %Spear.Event{body: 1, type: ^type}

      Spear.cancel_subscription(c.conn, sub)
    end

    test "an octet-stream event is not JSON decoded", c do
      body = :binary.copy(<<0>>, Enum.random(1..25))
      event = Spear.Event.new("octet-kind", body, content_type: "application/octet-stream")
      :ok = Spear.append([event], c.conn, c.stream_name)
      assert [%Spear.Event{body: ^body}] = Spear.stream!(c.conn, c.stream_name) |> Enum.to_list()
    end
  end

  defp random_stream_name do
    "Spear.Test-" <> Spear.Event.uuid_v4()
  end

  defp random_event do
    Spear.Event.new("test-event", %{})
  end

  defp random_events do
    Stream.iterate(0, &(&1 + 1)) |> Stream.map(&Spear.Event.new("counter-test", &1))
  end

  defp maximum_append_size_error do
    %Spear.Grpc.Response{
      data: "",
      message: "Maximum Append Size of #{@max_append_bytes} Exceeded.",
      status: :invalid_argument,
      status_code: 3
    }
  end
end
