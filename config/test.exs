import Config

config :spear, Spear.Test.ClientFixture, connection_string: "esdb://localhost:2113"

config :spear, :config,
  connection_string: "esdb://admin:changeit@localhost:2113?tls=true",
  mint_opts: [
    transport_opts: [
      cacertfile: Path.join([__DIR__ | ~w(.. certs ca ca.crt)])
    ]
  ]
