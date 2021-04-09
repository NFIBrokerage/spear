defmodule SpearTest do
  use ExUnit.Case, async: true

  alias Spear.Protos.EventStore.Client.Streams.ReadResp

  setup_all do
    [conn: start_supervised!({Spear.Connection, connection_string: "http://localhost:2113"})]
  end

  setup do
    [stream_name: random_stream_name()]
  end

  describe "given a stream contains events" do
    setup c do
      :ok =
        random_events()
        |> Stream.take(7)
        |> Spear.append(c.conn, c.stream_name, expect: :empty)

      on_exit(fn ->
        :ok = Spear.delete_stream(c.conn, c.stream_name)
      end)
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
      assert {:ok, events} = Spear.read_stream(c.conn, c.stream_name, direction: :backwards, from: :end)

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

      on_exit(fn ->
        :ok = Spear.cancel_subscription(c.conn, sub)
      end)

      for n <- 0..6//1 do
        assert_receive %Spear.Event{body: ^n}
      end
    end

    test "subscribing to the end of the stream emits no events in the stream", c do
      assert {:ok, sub} = Spear.subscribe(c.conn, self(), c.stream_name, from: :end)

      on_exit(fn ->
        :ok = Spear.cancel_subscription(c.conn, sub)
      end)

      refute_receive %Spear.Event{body: _}
    end

    test "a raw subscription will return ReadResp structs", c do
      assert {:ok, sub} = Spear.subscribe(c.conn, self(), c.stream_name, raw?: true)

      on_exit(fn ->
        :ok = Spear.cancel_subscription(c.conn, sub)
      end)

      for _n <- 0..6//1 do
        assert_receive %ReadResp{}
      end
    end
  end

  describe "given a subscription to a stream" do
    setup c do
      {:ok, sub} = Spear.subscribe(c.conn, self(), c.stream_name)

      on_exit(fn ->
        :ok = Spear.cancel_subscription(c.conn, sub)
      end)

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
      # why such large events? if we do this with the tiny events from
      # random_event/0 we get the same results but it's much slower and I want
      # to keep this test suite fast
      assert {:error, reason} =
               Stream.repeatedly(fn ->
                 Spear.Event.new("biggish-event", :binary.copy(<<0>>, 10_000),
                   content_type: "application/octet"
                 )
               end)
               |> Spear.append(c.conn, c.stream_name)

      assert reason == maximum_append_size_error()
    end

    test "if we try to write a gigantic event, we get a gRPC error", c do
      big_event =
        Spear.Event.new("biggish-event", :binary.copy(<<0>>, 1_048_756 + 1),
          content_type: "application/octet"
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
      message: "Maximum Append Size of 1048576 Exceeded.",
      status: :invalid_argument,
      status_code: 3
    }
  end
end
