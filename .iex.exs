make_server = fn ->
  host = System.get_env("EVENTSTORE_HOST") || "localhost"

  secure_params = [
    connection_string: "esdb://admin:changeit@#{host}:2113?tls=true",
    mint_opts: [
      transport_opts: [
        cacertfile: Path.join([__DIR__, "eventstoredb", "certs", "ca", "ca.crt"])
      ]
    ]
  ]

  _insecure_params = [
    connection_string: "esdb://#{host}:2113"
  ]

  {:ok, pid} = Spear.Connection.start_link(secure_params)

  pid
end

conn = make_server.()
