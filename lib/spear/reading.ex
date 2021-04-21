defmodule Spear.Reading do
  @moduledoc false

  # Helper functions for reading streams

  alias Spear.Records.{Streams, Persistent}
  require Streams
  require Persistent

  import Spear.Records.Shared,
    only: [
      empty: 0,
      stream_identifier: 1
    ]

  @uuid Streams.read_req_options_uuid_option(content: {:string, empty()})

  def decode_read_response(Streams.read_resp(content: {kind, _body}) = read_resp) do
    case kind do
      :event -> Spear.Event.from_read_response(read_resp)
      :checkpoint -> Spear.Filter.Checkpoint.from_read_response(read_resp)
    end
  end

  def decode_read_response(Persistent.read_resp() = read_resp) do
    Spear.Event.from_read_response(read_resp)
  end

  def build_read_request(params) do
    Streams.read_req(
      options:
        Streams.read_req_options(
          stream_option: map_stream(params.stream, params.from),
          read_direction: map_direction(params.direction),
          resolve_links: params.resolve_links?,
          count_option: {:count, params.max_count},
          filter_option: map_filter(nil),
          uuid_option: @uuid
        )
    )
  end

  def build_subscribe_request(params) do
    message =
      Streams.read_req(
        options:
          Streams.read_req_options(
            stream_option: map_stream(params.stream, params.from),
            read_direction: map_direction(params.direction),
            resolve_links: params.resolve_links?,
            count_option: {:subscription, Streams.read_req_options_subscription_options()},
            filter_option: map_filter(params.filter),
            uuid_option: @uuid
          )
      )

    %Spear.Request{
      api: {Spear.Records.Streams, :Read},
      messages: [message],
      credentials: params.credentials
    }
    |> Spear.Request.expand()
  end

  defp map_stream(:all, from) do
    {:all, Streams.read_req_options_all_options(all_option: map_all_position(from))}
  end

  defp map_stream(stream_name, from) when is_binary(stream_name) do
    {:stream,
     Streams.read_req_options_stream_options(
       stream_identifier: stream_identifier(streamName: stream_name),
       revision_option: map_stream_revision(from)
     )}
  end

  defp map_all_position(Streams.read_resp() = read_resp) do
    read_resp
    |> Spear.Event.from_read_response(link?: true)
    |> map_all_position()
  end

  defp map_all_position(%Spear.Event{
         metadata: %{commit_position: commit, prepare_position: prepare}
       }) do
    {:position,
     Streams.read_req_options_position(commit_position: commit, prepare_position: prepare)}
  end

  defp map_all_position(%Spear.Filter.Checkpoint{
         commit_position: commit,
         prepare_position: prepare
       }) do
    {:position,
     Streams.read_req_options_position(commit_position: commit, prepare_position: prepare)}
  end

  defp map_all_position(:start), do: {:start, empty()}

  defp map_all_position(:end), do: {:end, empty()}

  defp map_stream_revision(Streams.read_resp() = read_resp) do
    read_resp
    |> Spear.Event.from_read_response(link?: true)
    |> map_stream_revision()
  end

  defp map_stream_revision(%Spear.Event{metadata: %{stream_revision: revision}}),
    do: {:revision, revision}

  defp map_stream_revision(:start), do: {:start, empty()}
  defp map_stream_revision(n) when is_integer(n), do: {:revision, n}
  defp map_stream_revision(:end), do: {:end, empty()}

  defp map_filter(%Spear.Filter{} = filter),
    do: {:filter, Spear.Filter._to_filter_options(filter)}

  defp map_filter(nil), do: {:no_filter, empty()}

  defp map_direction(:forwards), do: :Forwards
  defp map_direction(:backwards), do: :Backwards
end
