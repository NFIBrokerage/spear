make_server = fn ->
  secure_params = [
    connection_string: "esdb://admin:changeit@localhost:2113?tls=true",
    mint_opts: [
      transport_opts: [
        cacertfile: Path.join([__DIR__, "certs", "ca", "ca.crt"])
      ]
    ]
  ]

  _insecure_params = [
    connection_string: "esdb://localhost:2113"
  ]

  {:ok, pid} = Spear.Connection.start_link(secure_params)

  pid
end

get_event_and_ack = fn conn, sub ->
  receive do
    %Spear.Event{} = event ->
      :ok = Spear.ack(conn, sub, event)

      event

  after
    3_000 -> :no_events
  end
end

get_event_and_nack = fn conn, sub, action ->
  receive do
    %Spear.Event{} = event ->
      :ok = Spear.nack(conn, sub, event, action: action)

      event

  after
    3_000 -> :no_events
  end
end

stream = "spear_test_stream_repeatedly"
group = "spear_iex"

conn = make_server.()

# subscribe = fn ->
#   import Spear.Filter
#
#   Spear.subscribe(conn, self(), :all, filter: ~f/grpc-/pt)
# end
