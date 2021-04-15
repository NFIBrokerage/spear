import Config

config :spear, Spear.Test.ClientFixture, connection_string: "esdb://localhost:2113"

config :spear, :config,
  connection_string: "esdb://localhost:2113?tls=true",
  opts: [
    transport_opts: [
      cacertfile: Path.join([__DIR__ | ~w(.. certs ca ca.crt)])
    ]
  ],
  credentials: {"admin", "changeit"}
