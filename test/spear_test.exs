defmodule SpearTest do
  use ExUnit.Case, async: true

  @moduletag :capture_log

  import Spear.Records.Streams, only: [read_resp: 0, read_resp: 1]
  import Spear.Uuid, only: [uuid_v4: 0]
  import VersionHelper

  @max_append_bytes 1_048_576
  @checkpoint_after 32 * 32 * 32

  @config Application.fetch_env!(:spear, :config)

  setup do
    conn = start_supervised!({Spear.Connection, @config})

    [
      conn: conn,
      stream_name: random_stream_name(),
      user: random_user(),
      password: uuid_v4()
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

    test "the :from option for reading is inclusive", c do
      [event] = Spear.stream!(c.conn, c.stream_name, from: :start) |> Enum.take(1)
      assert [^event] = Spear.stream!(c.conn, c.stream_name, from: event) |> Enum.take(1)

      assert [^event] =
               Spear.stream!(c.conn, c.stream_name, from: event.metadata.stream_revision)
               |> Enum.take(1)

      {:ok, events} = Spear.read_stream(c.conn, c.stream_name, from: :start)
      [event] = Enum.take(events, 1)
      {:ok, events} = Spear.read_stream(c.conn, c.stream_name, from: event)
      assert [^event] = Enum.take(events, 1)
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

    test "a stream may be streamed backwards", c do
      to_event_numbers = fn events -> Stream.map(events, & &1.body) |> Enum.to_list() end
      expected_event_numbers = Enum.to_list(6..0)

      assert ^expected_event_numbers =
               Spear.stream!(c.conn, c.stream_name, direction: :backwards, from: :end)
               |> to_event_numbers.()

      # and with read_stream/3
      assert {:ok, events} =
               Spear.read_stream(c.conn, c.stream_name, direction: :backwards, from: :end)

      assert to_event_numbers.(events) == expected_event_numbers
    end

    test "reading the stream raw returns ReadResp records", c do
      all_expected_type? = &Enum.all?(&1, fn message -> match?(read_resp(), message) end)

      assert Spear.stream!(c.conn, c.stream_name, raw?: true) |> all_expected_type?.()

      # and same with read_stream/3
      assert {:ok, events} = Spear.read_stream(c.conn, c.stream_name, raw?: true)
      assert all_expected_type?.(events)
    end

    @tag compatible(">= 21.10.0")
    test "stream!/3 and read_stream/3 may pass a filter on the :all stream", c do
      filter = %Spear.Filter{
        on: :stream_name,
        by: [c.stream_name],
        checkpoint_after: @checkpoint_after
      }

      assert {:ok, events} = Spear.read_stream(c.conn, :all, filter: filter)
      assert Enum.count(events) == 7

      assert Spear.stream!(c.conn, :all, filter: filter) |> Enum.count() == 7
    end

    test "subscribing at the beginning of a stream emits all of the events", c do
      assert {:ok, sub} = Spear.subscribe(c.conn, self(), c.stream_name, from: :start)

      for n <- 0..6 do
        assert_receive %Spear.Event{body: ^n, metadata: %{subscription: ^sub}}
      end

      :ok = Spear.cancel_subscription(c.conn, sub)
    end

    test "subscribing to the end of the stream emits no events in the stream", c do
      assert {:ok, sub} = Spear.subscribe(c.conn, self(), c.stream_name, from: :end)

      :ok = Spear.cancel_subscription(c.conn, sub)

      refute_receive %Spear.Event{body: _}
    end

    test "a raw subscription will return ReadResp records", c do
      assert {:ok, sub} = Spear.subscribe(c.conn, self(), c.stream_name, raw?: true)

      for _n <- 0..6 do
        assert_receive {^sub, read_resp()}
      end

      :ok = Spear.cancel_subscription(c.conn, sub)
    end

    test "deleting a stream makes it read as an empty list", c do
      assert Spear.delete_stream(c.conn, c.stream_name) == :ok

      assert Spear.stream!(c.conn, c.stream_name) |> Enum.to_list() == []

      assert {:ok, metadata} = Spear.get_stream_metadata(c.conn, c.stream_name)
      assert metadata.truncate_before |> is_integer()
    end

    test "a deletion request will fail if the expectation mismatches", c do
      assert {:error,
              %Spear.Grpc.Response{
                data: "",
                message: message,
                status: :failed_precondition,
                status_code: 9
              }} = Spear.delete_stream(c.conn, c.stream_name, expect: :empty)

      assert message =~
               "Append failed due to WrongExpectedVersion. Stream: #{c.stream_name}, Expected version: -1, Actual version: "

      assert {:error,
              %Spear.Grpc.Response{
                data: "",
                message: message,
                status: :failed_precondition,
                status_code: 9
              }} = Spear.delete_stream(c.conn, c.stream_name, expect: 3)

      assert message =~
               "Append failed due to WrongExpectedVersion. Stream: #{c.stream_name}, Expected version: 3, Actual version: "
    end

    test "a user can be CRUD-ed", c do
      login_name = c.user.login_name
      full_name = c.user.full_name
      password = c.password
      groups = []

      assert Spear.create_user(c.conn, full_name, login_name, password, groups) == :ok

      metadata = %Spear.StreamMetadata{acl: Spear.Acl.allow_all()}
      assert Spear.set_stream_metadata(c.conn, c.stream_name, metadata) == :ok

      assert {:ok, %Spear.User{full_name: ^full_name, login_name: ^login_name, groups: ^groups}} =
               Spear.user_details(c.conn, login_name)

      full_name_updated = full_name <> " updated"

      assert Spear.update_user(c.conn, full_name_updated, login_name, password, groups) == :ok

      assert {:ok,
              %Spear.User{full_name: ^full_name_updated, login_name: ^login_name, groups: ^groups}} =
               Spear.user_details(c.conn, login_name)

      assert {:ok, _events} =
               Spear.read_stream(c.conn, c.stream_name, credentials: {login_name, password})

      assert Spear.delete_user(c.conn, login_name) == :ok

      assert {:error, %Spear.Grpc.Response{status: :not_found}} =
               Spear.user_details(c.conn, login_name)
    end

    test "a disabled user cannot read from a stream", c do
      login_name = c.user.login_name
      full_name = c.user.full_name
      password = c.password
      groups = []

      assert Spear.create_user(c.conn, full_name, login_name, password, groups) == :ok

      assert Spear.disable_user(c.conn, login_name) == :ok

      acl = %Spear.Acl{read: [login_name, "$admins"], write: [login_name, "$admins"]}
      metadata = %Spear.StreamMetadata{acl: acl}
      assert Spear.set_stream_metadata(c.conn, c.stream_name, metadata) == :ok
      assert {:ok, %{acl: ^acl}} = Spear.get_stream_metadata(c.conn, c.stream_name)

      assert {:ok, %Spear.User{login_name: ^login_name, enabled?: false}} =
               Spear.user_details(c.conn, login_name)

      assert {:error, reason} =
               Spear.append([random_event()], c.conn, c.stream_name,
                 credentials: {login_name, password}
               )

      assert reason.message =~ "401"

      assert {:error, ^reason} =
               Spear.read_stream(c.conn, c.stream_name, credentials: {login_name, password})

      assert Spear.enable_user(c.conn, login_name) == :ok

      assert {:ok, _events} =
               Spear.read_stream(c.conn, c.stream_name, credentials: {login_name, password})

      assert Spear.delete_user(c.conn, login_name) == :ok
    end

    test "a psub can be ack-ed and nack-ed", c do
      group = uuid_v4()
      settings = %Spear.PersistentSubscription.Settings{}
      assert Spear.create_persistent_subscription(c.conn, c.stream_name, group, settings) == :ok

      assert {:ok, sub} =
               Spear.connect_to_persistent_subscription(c.conn, self(), c.stream_name, group)

      assert_receive %Spear.Event{metadata: %{stream_revision: 0}} = event
      # only receive one event at a time with default buffer_size
      refute_receive _

      assert Spear.ack(c.conn, sub, event) == :ok
      assert_receive %Spear.Event{metadata: %{stream_revision: 1}} = event

      assert Spear.nack(c.conn, sub, event, action: :retry) == :ok
      assert_receive %Spear.Event{metadata: %{stream_revision: 1}} = event

      assert Spear.ack(c.conn, sub, event) == :ok
      assert_receive %Spear.Event{metadata: %{stream_revision: 2}}

      assert Spear.cancel_subscription(c.conn, sub) == :ok

      assert Spear.delete_persistent_subscription(c.conn, c.stream_name, group) == :ok
    end

    @tag :flaky
    @tag compatible(">= 21.6.0")
    test "a psub to :all works as expected", c do
      group = uuid_v4()
      settings = %Spear.PersistentSubscription.Settings{}

      filter = %Spear.Filter{
        on: :stream_name,
        by: [c.stream_name],
        checkpoint_after: @checkpoint_after
      }

      assert Spear.create_persistent_subscription(c.conn, :all, group, settings,
               from: :start,
               filter: filter
             ) == :ok

      assert {:ok, sub} = Spear.connect_to_persistent_subscription(c.conn, self(), :all, group)

      events = collect_psub_events(c.conn, sub)

      assert Spear.cancel_subscription(c.conn, sub) == :ok

      assert Spear.delete_persistent_subscription(c.conn, :all, group) == :ok

      assert length(events) == 7
      assert Enum.all?(events, &(&1.metadata.stream_name == c.stream_name))
    end
  end

  describe "given a subscription to a stream" do
    setup c do
      {:ok, sub} = Spear.subscribe(c.conn, self(), c.stream_name)

      [sub: sub]
    end

    test "appending an event emits a message to the subscription", c do
      # note that we are not matching on ^event
      # because when an event is appended, the EventStoreDB slaps a bunch of
      # metadata on it like timestamp of commit and such
      Spear.append([random_event()], c.conn, c.stream_name)
      assert_receive %Spear.Event{}

      Spear.append([random_event()], c.conn, c.stream_name)
      assert_receive %Spear.Event{}
    end

    test "closing the subscription emits an {:eos, sub, :closed} message", c do
      assert GenServer.call(c.conn, :close) == {:ok, :closed}
      assert_receive {:eos, sub, :closed}
      assert sub == c.sub
    end

    test "a keep-alive timeout disconnects the conn and the conn reconnects", c do
      send(c.conn, :keep_alive_expired)
      assert_receive {:eos, sub, :closed}
      assert sub == c.sub
      assert Spear.ping(c.conn) == :pong
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

    # this test also shows the nice multiplexing power of this connection genserver
    test "attempting to append during a connection close gives {:error, :closed}", c do
      test_proc = self()

      append =
        Task.async(fn ->
          Stream.repeatedly(fn ->
            send(test_proc, :emitting_event)
            Spear.Event.new("tiny_event", 0)
          end)
          |> Spear.append(c.conn, c.stream_name, timeout: :infinity)
        end)

      assert_receive :emitting_event

      assert GenServer.call(c.conn, :close) == {:ok, :closed}

      assert Task.await(append) == {:error, :closed}
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

    @tag :flaky
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

      for n <- 1..4 do
        assert_receive %Spear.Event{body: ^n}
      end

      Spear.cancel_subscription(c.conn, sub)

      # and it works with a regex/binary
      regex = Regex.compile!("^" <> prefix)
      filter = %Spear.Filter{on: :stream_name, by: regex, checkpoint_after: @checkpoint_after}
      {:ok, sub} = Spear.subscribe(c.conn, self(), :all, filter: filter)

      assert_receive %Spear.Event{body: 0}, 1_000

      for n <- 1..4 do
        assert_receive %Spear.Event{body: ^n}
      end

      Spear.cancel_subscription(c.conn, sub)
    end

    test "the exclude_system_events/0 filter produces non-system events", c do
      :ok = [random_event()] |> Spear.append(c.conn, c.stream_name)

      filter =
        Spear.Filter.exclude_system_events()
        |> Spear.Filter.checkpoint_after(@checkpoint_after)

      {:ok, sub} = Spear.subscribe(c.conn, self(), :all, filter: filter)

      assert_receive %Spear.Event{type: type}

      refute match?("$" <> _, type)

      Spear.cancel_subscription(c.conn, sub)
    end

    test "a subscription can pick up from where it left off with a Spear.Event", c do
      filter = %Spear.Filter{
        on: :stream_name,
        by: [c.stream_name],
        checkpoint_after: @checkpoint_after
      }

      type = "pickup-test"

      event = Spear.Event.new(type, 0)
      :ok = Spear.append([event], c.conn, c.stream_name)

      {:ok, sub} = Spear.subscribe(c.conn, self(), :all, filter: filter)

      assert_receive %Spear.Event{body: 0, type: ^type} = first_event, 1_000

      Spear.cancel_subscription(c.conn, sub)

      next_event = Spear.Event.new(type, 1)
      :ok = Spear.append([next_event], c.conn, c.stream_name)

      {:ok, sub} = Spear.subscribe(c.conn, self(), :all, filter: filter, from: first_event)

      # note: exclusive on the :from
      refute_receive %Spear.Event{body: 0, type: ^type}
      assert_receive %Spear.Event{body: 1, type: ^type}

      Spear.cancel_subscription(c.conn, sub)
    end

    @tag :flaky
    test "a subscription can pick up from where it left off with a ReadResp", c do
      filter = %Spear.Filter{
        on: :stream_name,
        by: [c.stream_name],
        checkpoint_after: @checkpoint_after
      }

      type = "readresp-pickup-test"

      event = Spear.Event.new(type, 0)
      :ok = Spear.append([event], c.conn, c.stream_name)

      {:ok, sub} = Spear.subscribe(c.conn, self(), :all, filter: filter, raw?: true)

      assert_receive {^sub, read_resp(content: {:event, _}) = first_event}, 1_000
      assert %Spear.Event{body: 0, type: ^type} = Spear.Event.from_read_response(first_event)

      Spear.cancel_subscription(c.conn, sub)

      next_event = Spear.Event.new(type, 1)
      :ok = Spear.append([next_event], c.conn, c.stream_name)

      {:ok, sub} = Spear.subscribe(c.conn, self(), :all, filter: filter, from: first_event)

      # note: exclusive on the :from
      refute_receive %Spear.Event{body: 0, type: ^type}
      assert_receive %Spear.Event{body: 1, type: ^type}

      Spear.cancel_subscription(c.conn, sub)
    end

    @tag :flaky
    test "a subscription can pick up from a checkpoint", c do
      filter = %Spear.Filter{on: :stream_name, by: [c.stream_name]}
      type = "checkpoint-test"

      event = Spear.Event.new(type, 0)
      :ok = Spear.append([event], c.conn, c.stream_name)

      {:ok, sub} = Spear.subscribe(c.conn, self(), :all, filter: filter)

      assert_receive %Spear.Filter.Checkpoint{subscription: ^sub} = checkpoint

      Spear.cancel_subscription(c.conn, sub)

      next_event = Spear.Event.new(type, 1)
      :ok = Spear.append([next_event], c.conn, c.stream_name)

      filter = Spear.Filter.checkpoint_after(filter, @checkpoint_after)
      {:ok, sub} = Spear.subscribe(c.conn, self(), :all, filter: filter, from: checkpoint)

      assert_receive %Spear.Event{body: 1, type: ^type}, 1_000

      Spear.cancel_subscription(c.conn, sub)
    end

    test "a subscription to the end of the :all stream will pickup a new event", c do
      filter = %Spear.Filter{
        on: :stream_name,
        by: [c.stream_name],
        checkpoint_after: @checkpoint_after
      }

      type = "subscription-end-test"

      assert {:ok, sub} = Spear.subscribe(c.conn, self(), :all, filter: filter, from: :end)

      refute_receive %Spear.Event{type: ^type, body: 0}

      event = Spear.Event.new(type, 0)
      :ok = Spear.append([event], c.conn, c.stream_name)

      assert_receive %Spear.Event{type: ^type, body: 0}

      Spear.cancel_subscription(c.conn, sub)
    end

    test "an octet-stream event is not JSON decoded", c do
      body = :binary.copy(<<0>>, Enum.random(1..25))
      event = Spear.Event.new("octet-kind", body, content_type: "application/octet-stream")
      :ok = Spear.append([event], c.conn, c.stream_name)
      assert [%Spear.Event{body: ^body}] = Spear.stream!(c.conn, c.stream_name) |> Enum.to_list()
    end

    test "we may set the global ACL and then an unauthenticated user access fails", c do
      assert Spear.set_global_acl(c.conn, Spear.Acl.admins_only(), Spear.Acl.admins_only()) == :ok

      assert {:error, reason} =
               [random_event()]
               |> Spear.append(c.conn, c.stream_name, credentials: {"no one", "no pass"})

      assert reason.message == "Bad HTTP status code: 401, should be 200"

      # reset ACL
      assert Spear.set_global_acl(c.conn, Spear.Acl.allow_all(), Spear.Acl.admins_only()) == :ok
    end

    test "we map set a local ACL and then an unauthenticated user access fails", c do
      metadata = %Spear.StreamMetadata{acl: Spear.Acl.admins_only()}
      assert Spear.set_stream_metadata(c.conn, c.stream_name, metadata) == :ok

      assert {:error, reason} =
               [random_event()]
               |> Spear.append(c.conn, c.stream_name, credentials: {"no one", "no pass"})

      assert reason.message == "Bad HTTP status code: 401, should be 200"

      # reset ACL
      metadata = %Spear.StreamMetadata{acl: Spear.Acl.allow_all()}
      assert Spear.set_stream_metadata(c.conn, c.stream_name, metadata) == :ok
    end

    test "a server may be told it needs to do a keep-alive ping check", c do
      # this is mostly for coverage :(
      send(c.conn, :keep_alive)
      assert Spear.ping(c.conn) == :pong
    end

    test "you cannot operate on a user that does not exist", c do
      login_name = c.user.login_name
      full_name = c.user.full_name
      password = c.password

      not_found = %Spear.Grpc.Response{
        data: "",
        message: "User '#{login_name}' is not found.",
        status: :not_found,
        status_code: 5
      }

      assert {:error, ^not_found} = Spear.update_user(c.conn, full_name, login_name, password, [])
      assert {:error, ^not_found} = Spear.delete_user(c.conn, login_name)
      assert {:error, ^not_found} = Spear.disable_user(c.conn, login_name)
      assert {:error, ^not_found} = Spear.enable_user(c.conn, login_name)
      assert {:error, ^not_found} = Spear.reset_user_password(c.conn, login_name, password)

      assert {:error, ^not_found} =
               Spear.change_user_password(c.conn, login_name, password, password)
    end

    test "a user not in the `$ops` group cannot shut down the server", c do
      assert Spear.create_user(
               c.conn,
               c.user.full_name,
               c.user.login_name,
               c.password,
               _groups = []
             ) == :ok

      assert {:error, %Spear.Grpc.Response{status: :permission_denied}} =
               Spear.shutdown(c.conn, credentials: {c.user.login_name, c.password})

      assert Spear.ping(c.conn) == :pong

      assert Spear.delete_user(c.conn, c.user.login_name) == :ok
    end

    test "a scavenge can be started, followed, and deleted", c do
      assert {:ok, %Spear.Scavenge{result: :Started} = scavenge} = Spear.start_scavenge(c.conn)
      assert {:ok, sub} = Spear.subscribe(c.conn, self(), Spear.scavenge_stream(scavenge))
      assert_receive %Spear.Event{type: "$scavengeStarted"}
      assert_receive %Spear.Event{type: "$scavengeCompleted"}
      # cannot stop a scavenge after it is complete, get a not-found error
      assert {:error, reason} = Spear.stop_scavenge(c.conn, scavenge.id)
      assert reason.status == :not_found
      Spear.cancel_subscription(c.conn, sub)
    end

    @tag :operations
    test "a request to merge indices succeeds", c do
      assert Spear.merge_indexes(c.conn) == :ok
    end

    @tag :operations
    test "a request for the node to resign succeeds", c do
      assert Spear.resign_node(c.conn) == :ok
    end

    @tag :operations
    test "a request to set the node priority succeeds", c do
      assert Spear.set_node_priority(c.conn, 1) == :ok
    end

    @tag :operations
    test "a request to restart persistent subscriptions succeeds", c do
      assert Spear.restart_persistent_subscriptions(c.conn) == :ok
    end

    @tag compatible(">= 21.0.0")
    test "the cluster info shows one active node on localhost", c do
      assert {:ok, [%Spear.ClusterMember{address: "127.0.0.1", alive?: true}]} =
               Spear.cluster_info(c.conn)
    end

    test "a persistent subscription may be CRUD-ed", c do
      settings = %Spear.PersistentSubscription.Settings{}
      stream = c.stream_name
      group = uuid_v4()

      has_this_psub? = fn subs ->
        Enum.any?(
          subs,
          &match?(%Spear.PersistentSubscription{stream_name: ^stream, group_name: ^group}, &1)
        )
      end

      assert Spear.create_persistent_subscription(c.conn, stream, group, settings) == :ok
      assert {:ok, subs} = Spear.list_persistent_subscriptions(c.conn)
      assert has_this_psub?.(subs)

      assert Spear.update_persistent_subscription(c.conn, stream, group, settings) == :ok
      assert {:ok, subs} = Spear.list_persistent_subscriptions(c.conn)
      assert has_this_psub?.(subs)

      assert Spear.delete_persistent_subscription(c.conn, stream, group) == :ok
      assert {:ok, subs} = Spear.list_persistent_subscriptions(c.conn)
      refute has_this_psub?.(subs)
    end

    test "you cannot create a persistent subscription that already exists", c do
      settings = %Spear.PersistentSubscription.Settings{}
      stream = c.stream_name
      group = uuid_v4()

      assert Spear.create_persistent_subscription(c.conn, stream, group, settings) == :ok

      assert {:error, reason} =
               Spear.create_persistent_subscription(c.conn, stream, group, settings)

      assert reason.status == :already_exists

      Spear.delete_persistent_subscription(c.conn, stream, group)
    end

    test "you cannot update a persistent subscription that does not exist", c do
      settings = %Spear.PersistentSubscription.Settings{}
      stream = c.stream_name
      group = uuid_v4()

      assert {:error, reason} =
               Spear.update_persistent_subscription(c.conn, stream, group, settings)

      assert reason.message == "Subscription group #{group} on stream #{stream} does not exist." or
               reason.message == "Unexpected UpdatePersistentSubscriptionResult: DoesNotExist"

      assert reason.status in [:unknown, :not_found]
    end

    test "you cannot delete a persistent subscription that does not exist", c do
      stream = c.stream_name
      group = uuid_v4()

      assert {:error, reason} = Spear.delete_persistent_subscription(c.conn, stream, group)
      assert reason.status == :not_found
    end

    test "you cannot connect to a persistent subscription that does not exist", c do
      stream = c.stream_name
      group = uuid_v4()

      assert {:error, reason} =
               Spear.connect_to_persistent_subscription(c.conn, self(), stream, group)

      assert reason.status == :not_found
    end

    test "a persistent subscription shows {:eos, :dropped} on deletion", c do
      settings = %Spear.PersistentSubscription.Settings{}
      stream = c.stream_name
      group = uuid_v4()
      assert Spear.create_persistent_subscription(c.conn, stream, group, settings) == :ok

      assert {:ok, sub} = Spear.connect_to_persistent_subscription(c.conn, self(), stream, group)

      # empty stream
      refute_receive %Spear.Event{metadata: %{subscription: ^sub}}

      assert Spear.delete_persistent_subscription(c.conn, stream, group) == :ok

      assert_receive {:eos, ^sub, :dropped}
    end

    test "reading and subscribing to (projected) category streams works", c do
      id = uuid_v4() |> String.replace("-", "")
      prefix = "Spear.#{id}.CategoryTest"
      category = "$ce-" <> prefix
      # round 1: add events from one stream
      {:ok, sub} = Spear.subscribe(c.conn, self(), category)

      stream_name = prefix <> "-" <> uuid_v4()
      :ok = random_events() |> Stream.take(3) |> Spear.append(c.conn, stream_name, expect: :empty)

      assert_receive %Spear.Event{
        body: 0,
        metadata: %{subscription: ^sub, stream_name: ^stream_name}
      }

      assert_receive %Spear.Event{
        body: 1,
        metadata: %{subscription: ^sub, stream_name: ^stream_name}
      }

      assert_receive %Spear.Event{
        body: 2,
        metadata: %{subscription: ^sub, stream_name: ^stream_name}
      }

      :ok = Spear.cancel_subscription(c.conn, sub)

      events = Spear.stream!(c.conn, stream_name) |> Enum.to_list()
      assert Enum.count(events) == 3
      last_event = List.last(events)

      # round 2: add events from another stream in the category
      {:ok, sub} = Spear.subscribe(c.conn, self(), category, from: last_event)

      stream_name = prefix <> "-" <> uuid_v4()
      :ok = random_events() |> Stream.take(3) |> Spear.append(c.conn, stream_name, expect: :empty)

      assert_receive %Spear.Event{
        body: 0,
        metadata: %{subscription: ^sub, stream_name: ^stream_name}
      }

      assert_receive %Spear.Event{
        body: 1,
        metadata: %{subscription: ^sub, stream_name: ^stream_name}
      }

      assert_receive %Spear.Event{
        body: 2,
        metadata: %{subscription: ^sub, stream_name: ^stream_name}
      }

      :ok = Spear.cancel_subscription(c.conn, sub)

      assert Spear.stream!(c.conn, category, from: last_event) |> Enum.count() == 4

      assert Spear.stream!(c.conn, category, from: :start, chunk_size: 2) |> Enum.count() == 6
    end

    @tag compatible(">= 21.0.0")
    test "a process may subscribe to stats updates with subscribe_to_stats/3", c do
      assert {:ok, subscription} = Spear.subscribe_to_stats(c.conn, self(), interval: 200)
      assert_receive stats when is_map(stats)
      assert_receive stats when is_map(stats)
      assert Spear.cancel_subscription(c.conn, subscription) == :ok

      assert {:ok, subscription} = Spear.subscribe_to_stats(c.conn, self(), raw?: true)
      assert_receive {^subscription, stats} when is_tuple(stats)
      assert Spear.cancel_subscription(c.conn, subscription) == :ok
    end

    @tag compatible(">= 21.6.0")
    test "append_batch/5 appends a batch of events", c do
      assert {:ok, batch_id, request_id} =
               random_events()
               |> Stream.take(5)
               |> Spear.append_batch(c.conn, :new, c.stream_name, expect: :empty)

      assert_receive %Spear.BatchAppendResult{
        result: :ok,
        batch_id: ^batch_id,
        request_id: ^request_id,
        revision: revision
      }

      assert {:ok, batch_id, request_id} =
               random_events()
               |> Stream.drop(5)
               |> Stream.take(5)
               |> Spear.append_batch(c.conn, request_id, c.stream_name, expect: revision)

      assert_receive %Spear.BatchAppendResult{
        result: :ok,
        batch_id: ^batch_id,
        request_id: ^request_id
      }

      assert {:ok, batch_id, request_id} =
               random_events()
               |> Stream.drop(10)
               |> Stream.take(5)
               |> Spear.append_batch(c.conn, request_id, c.stream_name, expect: :exists)

      assert_receive %Spear.BatchAppendResult{
        result: :ok,
        batch_id: ^batch_id,
        request_id: ^request_id
      }

      assert {:ok, batch_id, request_id} =
               random_events()
               |> Stream.drop(15)
               |> Stream.take(5)
               |> Spear.append_batch(c.conn, request_id, c.stream_name)

      assert_receive %Spear.BatchAppendResult{
        result: :ok,
        batch_id: ^batch_id,
        request_id: ^request_id
      }

      assert Spear.cancel_subscription(c.conn, request_id) == :ok

      assert Spear.stream!(c.conn, c.stream_name) |> Enum.map(& &1.body) == Enum.to_list(0..19)
    end

    @tag compatible(">= 21.6.0")
    test "append_batch/5 can fragment with the :done? flag and :batch_id", c do
      assert {:ok, batch_id, request_id} =
               random_events()
               |> Stream.take(5)
               |> Spear.append_batch(c.conn, :new, c.stream_name, done?: false)

      assert {:ok, ^batch_id, ^request_id} =
               random_events()
               |> Stream.drop(5)
               |> Stream.take(5)
               |> Spear.append_batch(c.conn, request_id, c.stream_name,
                 done?: true,
                 batch_id: batch_id
               )

      assert_receive %Spear.BatchAppendResult{
        result: :ok,
        batch_id: ^batch_id,
        request_id: ^request_id
      }

      refute_receive _

      assert Spear.cancel_subscription(c.conn, request_id) == :ok

      assert Spear.stream!(c.conn, c.stream_name) |> Enum.map(& &1.body) == Enum.to_list(0..9)
    end

    @tag compatible(">= 21.6.0")
    test "an incomplete append_batch/5 fragment will time out", c do
      assert {:ok, batch_id, request_id} =
               random_events()
               |> Stream.take(5)
               |> Spear.append_batch(c.conn, :new, c.stream_name, done?: false)

      assert_receive %Spear.BatchAppendResult{
                       result:
                         {:error,
                          %Spear.Grpc.Response{message: "Timeout", status: :deadline_exceeded}},
                       batch_id: ^batch_id,
                       request_id: ^request_id
                     },
                     5_000

      refute_receive _

      assert Spear.cancel_subscription(c.conn, request_id) == :ok

      assert Spear.stream!(c.conn, c.stream_name) |> Enum.to_list() == []
    end

    @tag compatible(">= 21.10.0")
    test "append_batch/5 with a deadline in the past will fail", c do
      deadline = {0, 0}

      assert {:ok, batch_id, request_id} =
               random_events()
               |> Stream.take(5)
               |> Spear.append_batch(c.conn, :new, c.stream_name, deadline: deadline)

      assert_receive %Spear.BatchAppendResult{
        result: {:error, %Spear.Grpc.Response{message: "Timeout", status: :deadline_exceeded}},
        batch_id: ^batch_id,
        request_id: ^request_id
      }

      refute_receive _

      assert Spear.cancel_subscription(c.conn, request_id) == :ok

      assert Spear.stream!(c.conn, c.stream_name) |> Enum.to_list() == []
    end

    @tag compatible(">= 21.6.0")
    test "the append_batch_stream/2 helper maps a stream of batches, appends all", c do
      stream_a = c.stream_name
      stream_b = random_stream_name()

      [
        {stream_a, Stream.take(random_events(), 5), expect: :empty},
        {stream_a, Stream.take(random_events(), 5)},
        {stream_b, Stream.take(random_events(), 5), expect: :empty}
      ]
      |> Spear.append_batch_stream(c.conn)
      |> Enum.each(fn ack ->
        assert %Spear.BatchAppendResult{result: :ok} = ack
      end)

      assert Spear.stream!(c.conn, stream_a) |> Enum.count() == 10
      assert Spear.stream!(c.conn, stream_b) |> Enum.count() == 5
    end

    @tag compatible(">= 21.10.0")
    test "the server version can be determined with get_server_version/2", c do
      assert match?({:ok, version} when is_binary(version), Spear.get_server_version(c.conn))
    end

    @tag compatible(">= 21.10.0")
    test "the server's implemented RPCs can be determined with get_supported_rpcs/2", c do
      assert match?({:ok, [%Spear.SupportedRpc{} | _]}, Spear.get_supported_rpcs(c.conn))
    end
  end

  test "park_stream/2 composes a proper parking stream" do
    assert Spear.park_stream("MyStream", "MyGroup") ==
             "$persistentsubscription-MyStream::MyGroup-parked"
  end

  defp random_stream_name do
    "Spear.Test-" <> uuid_v4()
  end

  defp random_event do
    Spear.Event.new("test-event", %{})
  end

  defp random_events do
    Stream.iterate(0, &(&1 + 1)) |> Stream.map(&Spear.Event.new("counter-test", &1))
  end

  defp random_user do
    %Spear.User{full_name: "Spear Test User", login_name: "spear-test-#{uuid_v4()}", groups: []}
  end

  defp maximum_append_size_error do
    %Spear.Grpc.Response{
      data: "",
      message: "Maximum Append Size of #{@max_append_bytes} Exceeded.",
      status: :invalid_argument,
      status_code: 3
    }
  end

  defp collect_psub_events(conn, subscription, acc \\ []) do
    receive do
      %Spear.Event{} = event ->
        Spear.ack(conn, subscription, event)
        collect_psub_events(conn, subscription, [event | acc])
    after
      500 -> :lists.reverse(acc)
    end
  end
end
