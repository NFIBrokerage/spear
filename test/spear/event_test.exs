defmodule Spear.EventTest do
  use ExUnit.Case, async: true

  test "a datastructure can produce a seemingly valid UUIDv4" do
    assert Spear.Event.uuid_v4(%{"foo" => "bar"}) == "33323639-3934-4339-b332-363939343339"
  end

  describe "given a projected event" do
    setup :projected_event

    test "the spear event follows the link", c do
      assert %Spear.Event{body: %{"hello" => "world"}} = Spear.Event.from_read_response(c.event)
    end

    test "force-following the link produces a spear event with link body", c do
      assert %Spear.Event{id: "5fc66e27-" <> _} =
               Spear.Event.from_read_response(c.event, link?: true)
    end
  end

  describe "given a deleted event" do
    setup :deleted_event

    test "a spear event shows the link body", c do
      assert %Spear.Event{id: "b58ab56c-" <> _} =
               Spear.Event.from_read_response(c.event)
    end
  end

  defp projected_event(_c), do: [event: projected_event()]

  defp projected_event do
    # a fixture event from my eventstore
    # looks to be from one of the tests
    # iex> Spear.stream!(conn, "$streams", raw?: true, from: :end, direction: :backwards) |> Enum.take(1) |> List.first()
    {:"event_store.client.streams.ReadResp",
     {:event,
      {:"event_store.client.streams.ReadResp.ReadEvent",
       {:"event_store.client.streams.ReadResp.ReadEvent.RecordedEvent",
        {:"event_store.client.shared.UUID",
         {:string, "9e3a8bcf-0c22-4a38-85c6-2054a0342ec8"}},
        {:"event_store.client.shared.StreamIdentifier", "MySpearDemo"}, 0,
        18446744073709551615, 18446744073709551615,
        [
          {"content-type", "application/json"},
          {"type", "IExAndSpear"},
          {"created", "16182579177572156"}
        ], "", "{\"hello\":\"world\"}"},
       {:"event_store.client.streams.ReadResp.ReadEvent.RecordedEvent",
        {:"event_store.client.shared.UUID",
         {:string, "5fc66e27-b9ff-44fe-b463-9bfc29e05a01"}},
        {:"event_store.client.shared.StreamIdentifier", "$streams"}, 1949,
        18446744073709551615, 18446744073709551615,
        [
          {"content-type", "application/octet-stream"},
          {"type", "$>"},
          {"created", "16182579177661961"}
        ],
        "{\"$v\":\"1:-1:1:4\",\"$c\":8068857,\"$p\":8068857,\"$causedBy\":\"9e3a8bcf-0c22-4a38-85c6-2054a0342ec8\"}",
        "0@MySpearDemo"}, {:no_position, {:"event_store.client.shared.Empty"}}}}}
  end

  defp deleted_event(_c), do: [event: deleted_event()]

  def deleted_event do
    # this is an internal kind of event to EventStore that I pulled from my
    # local eventstore instance
    # iex> Spear.stream!(conn, "$et-$deleted", raw?: true, from: :end, direction: :backwards) |> Enum.take(1) |> List.first()
    {:"event_store.client.streams.ReadResp",
     {:event,
      {:"event_store.client.streams.ReadResp.ReadEvent", :undefined,
       {:"event_store.client.streams.ReadResp.ReadEvent.RecordedEvent",
        {:"event_store.client.shared.UUID",
         {:string, "b58ab56c-58c5-44f1-ba20-6e292a6310d6"}},
        {:"event_store.client.shared.StreamIdentifier", "$et-$deleted"}, 254,
        18446744073709551615, 18446744073709551615,
        [
          {"content-type", "application/octet-stream"},
          {"type", "$>"},
          {"created", "16182457401612475"}
        ],
        "{\"$v\":\"4:-1:1:4\",\"$c\":8039193,\"$p\":8039193,\"$deleted\":-1,\"$causedBy\":\"566823ae-f4a0-4288-9072-61870b7c0516\"}",
        "0@Spear.Test-fca49a09-e219-4292-a1b8-01a199dc4538"},
       {:no_position, {:"event_store.client.shared.Empty"}}}}}
  end
end
