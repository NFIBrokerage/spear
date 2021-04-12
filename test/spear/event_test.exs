defmodule Spear.EventTest do
  use ExUnit.Case, async: true

  test "a datastructure can produce a seemingly valid UUIDv4" do
    assert Spear.Event.uuid_v4(%{"foo" => "bar"}) == "33323639-3934-4339-b332-363939343339"
  end

  describe "given a projected event" do
    setup :projected_event

    test "the spear event follows the link", c do
      assert %Spear.Event{body: <<0, 0, 0, _::binary>>} = Spear.Event.from_read_response(c.event)
    end

    test "force-following the link produces a spear event with link body", c do
      assert %Spear.Event{body: "0@Spear.Test-a6b0" <> _} =
               Spear.Event.from_read_response(c.event, link?: true)
    end
  end

  describe "given a deleted event" do
    setup :deleted_event

    test "a spear event shows the link body", c do
      assert %Spear.Event{body: "0@Spear.Test-172af" <> _} =
               Spear.Event.from_read_response(c.event)
    end
  end

  defp projected_event(_c), do: [event: projected_event()]

  defp projected_event do
    # a fixture event from my eventstore
    # looks to be from one of the tests
    # iex> Spear.stream!(conn, "$streams", raw?: true) |> Enum.take(-1)
    %Spear.Protos.EventStore.Client.Streams.ReadResp{
      content:
        {:event,
         %Spear.Protos.EventStore.Client.Streams.ReadResp.ReadEvent{
           event: %Spear.Protos.EventStore.Client.Streams.ReadResp.ReadEvent.RecordedEvent{
             commit_position: 18_446_744_073_709_551_615,
             custom_metadata: "",
             data: <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>,
             id: %Spear.Protos.EventStore.Client.Shared.UUID{
               value: {:string, "7b44b3a1-ef45-4435-a931-aff40b889fa6"}
             },
             metadata: %{
               "content-type" => "application/octet-stream",
               "created" => "16182381307214066",
               "type" => "octet-kind"
             },
             prepare_position: 18_446_744_073_709_551_615,
             stream_identifier: %Spear.Protos.EventStore.Client.Shared.StreamIdentifier{
               streamName: "Spear.Test-a6b09656-0ec9-4acd-a24a-06a30013e83e"
             },
             stream_revision: 0
           },
           link: %Spear.Protos.EventStore.Client.Streams.ReadResp.ReadEvent.RecordedEvent{
             commit_position: 18_446_744_073_709_551_615,
             custom_metadata:
               "{\"$v\":\"1:-1:1:4\",\"$c\":1178658,\"$p\":1178658,\"$causedBy\":\"7b44b3a1-ef45-4435-a931-aff40b889fa6\"}",
             data: "0@Spear.Test-a6b09656-0ec9-4acd-a24a-06a30013e83e",
             id: %Spear.Protos.EventStore.Client.Shared.UUID{
               value: {:string, "09efcdc8-fd88-4e1b-bac8-8ed0c6f6bee7"}
             },
             metadata: %{
               "content-type" => "application/octet-stream",
               "created" => "16182381833305735",
               "type" => "$>"
             },
             prepare_position: 18_446_744_073_709_551_615,
             stream_identifier: %Spear.Protos.EventStore.Client.Shared.StreamIdentifier{
               streamName: "$streams"
             },
             stream_revision: 1467
           },
           position: {:no_position, %Spear.Protos.EventStore.Client.Shared.Empty{}}
         }}
    }
  end

  defp deleted_event(_c), do: [event: deleted_event()]

  def deleted_event do
    # this is an internal kind of event to EventStore that I pulled from my
    # local eventstore instance
    # iex> Spear.stream!(conn, "$et-$deleted", raw?: true, from: :end, direction: :backwards) |> Enum.take(1) |> List.first()
    %Spear.Protos.EventStore.Client.Streams.ReadResp{
      content:
        {:event,
         %Spear.Protos.EventStore.Client.Streams.ReadResp.ReadEvent{
           event: nil,
           link: %Spear.Protos.EventStore.Client.Streams.ReadResp.ReadEvent.RecordedEvent{
             commit_position: 18_446_744_073_709_551_615,
             custom_metadata:
               "{\"$v\":\"4:-1:1:4\",\"$c\":6455388,\"$p\":6455388,\"$deleted\":-1,\"$causedBy\":\"b1029b99-283d-41c2-b7bf-90adc1d905e9\"}",
             data: "0@Spear.Test-172afb92-ad28-4589-82e5-3c358031e2a4",
             id: %Spear.Protos.EventStore.Client.Shared.UUID{
               value: {:string, "91d6e024-8888-4782-aa0b-8b9c60c84a05"}
             },
             metadata: %{
               "content-type" => "application/octet-stream",
               "created" => "16182386815261258",
               "type" => "$>"
             },
             prepare_position: 18_446_744_073_709_551_615,
             stream_identifier: %Spear.Protos.EventStore.Client.Shared.StreamIdentifier{
               streamName: "$et-$deleted"
             },
             stream_revision: 216
           },
           position: {:no_position, %Spear.Protos.EventStore.Client.Shared.Empty{}}
         }}
    }
  end
end
