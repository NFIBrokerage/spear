use Mix.Config

config :spear, Spear.Test.ClientFixture, connection_string: "esdb://localhost:2113"

host = System.get_env("EVENTSTORE_HOST") || "localhost"

config :spear, :config,
  connection_string: "esdb://admin:changeit@#{host}:2113?tls=true",
  mint_opts: [
    transport_opts: [
      cacertfile: Path.join([__DIR__ | ~w(.. eventstoredb certs ca ca.crt)])
    ]
  ]
