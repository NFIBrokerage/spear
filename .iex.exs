make_server = fn ->
  params = [
    connection_string: "esdb://admin:changeit@localhost:2113?tls=false&keepAliveInterval=20000&keepAliveTimeout=20000",
    # mint_opts: [
    #   transport_opts: [
    #     cacertfile: Path.join([__DIR__, "certs", "ca", "ca.crt"])
    #   ]
    # ]
  ]

  {:ok, pid} = Spear.Connection.start_link(params)

  pid
end

conn = make_server.()

# subscribe = fn ->
#   import Spear.Filter
#
#   Spear.subscribe(conn, self(), :all, filter: ~f/grpc-/pt)
# end
