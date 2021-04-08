defmodule Spear.Reading do
  @moduledoc false

  # Helper functions for reading streams

  alias Spear.Protos.EventStore.Client.{
    Shared,
    Streams.ReadReq,
    Streams.ReadResp,
    Streams.Streams.Service
  }

  @uuid %ReadReq.Options.UUIDOption{content: {:string, %Shared.Empty{}}}

  @doc false
  def decode_next_message(message) do
    Spear.Grpc.decode_next_message(message, ReadResp)
  end

  def decode_read_response(%ReadResp{content: {kind, _body}} = read_resp) do
    case kind do
      :event -> Spear.Event.from_read_response(read_resp)
      :checkpoint -> Spear.Filter.Checkpoint.from_read_response(read_resp)
    end
  end

  def build_read_request(params) do
    %ReadReq{
      options: %ReadReq.Options{
        count_option: {:count, params.max_count},
        filter_option: map_filter(params.filter),
        read_direction: map_direction(params.direction),
        resolve_links: params.resolve_links?,
        stream_option: map_stream(params.stream, params.from),
        uuid_option: @uuid
      }
    }
  end

  def build_subscribe_request(params) do
    message = %ReadReq{
      options: %ReadReq.Options{
        count_option: {:subscription, %ReadReq.Options.SubscriptionOptions{}},
        filter_option: map_filter(params.filter),
        read_direction: map_direction(params.direction),
        resolve_links: params.resolve_links?,
        stream_option: map_stream(params.stream, params.from),
        uuid_option: @uuid
      }
    }

    %Spear.Request{
      service: Service,
      rpc: :Read,
      messages: [message]
    }
    |> Spear.Request.expand()
  end

  defp map_stream(:all, from),
    do: {:all, %ReadReq.Options.AllOptions{all_option: map_all_position(from)}}

  defp map_stream(stream_name, from) when is_binary(stream_name),
    do:
      {:stream,
       %ReadReq.Options.StreamOptions{
         revision_option: map_stream_revision(from),
         stream_identifier: %Shared.StreamIdentifier{streamName: stream_name}
       }}

  defp map_all_position(%ReadResp{} = read_resp) do
    read_resp
    |> Spear.Event.from_read_response(link?: true)
    |> map_all_position()
  end

  defp map_all_position(%Spear.Event{
         metadata: %{commit_position: commit, prepare_position: prepare}
       }),
       do:
         {:position,
          %ReadReq.Options.Position{commit_position: commit, prepare_position: prepare}}

  defp map_all_position(%Spear.Filter.Checkpoint{
         commit_position: commit,
         prepare_position: prepare
       }),
       do:
         {:position,
          %ReadReq.Options.Position{commit_position: commit, prepare_position: prepare}}

  defp map_all_position(:start), do: {:start, %Shared.Empty{}}

  defp map_all_position(%{commit_position: commit, prepare_position: prepare}),
    do: {:position, %ReadReq.Options.Position{commit_position: commit, prepare_position: prepare}}

  defp map_all_position(:end), do: {:end, %Shared.Empty{}}

  defp map_stream_revision(%ReadResp{} = read_resp) do
    read_resp
    |> Spear.Event.from_read_response(link?: true)
    |> map_stream_revision()
  end

  defp map_stream_revision(%Spear.Event{metadata: %{stream_revision: revision}}),
    do: {:revision, revision}

  defp map_stream_revision(:start), do: {:start, %Shared.Empty{}}
  defp map_stream_revision(n) when is_integer(n), do: {:revision, n}
  defp map_stream_revision(:end), do: {:end, %Shared.Empty{}}

  defp map_filter(%Spear.Filter{} = filter),
    do: {:filter, Spear.Filter._to_filter_options(filter)}

  defp map_filter(nil), do: {:no_filter, %Shared.Empty{}}

  defp map_direction(:forwards), do: :Forwards
  defp map_direction(:backwards), do: :Backwards

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
