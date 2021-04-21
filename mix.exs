defmodule Spear.MixProject do
  use Mix.Project

  @source_url "https://github.com/NFIBrokerage/spear"
  @version_file Path.join(__DIR__, ".version")
  @external_resource @version_file
  @version (case Regex.run(~r/^v([\d\.\w-]+)/, File.read!(@version_file), capture: :all_but_first) do
              [version] -> version
              nil -> "0.1.0"
            end)

  def project do
    [
      app: :spear,
      version: @version,
      elixir: "~> 1.7",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        credo: :test,
        coveralls: :test,
        "coveralls.html": :test,
        "coveralls.github": :test,
        inch: :dev,
        bless: :test,
        test: :test,
        dialyzer: :test
      ],
      name: "Spear",
      source_url: @source_url,
      deps: deps(),
      docs: docs(),
      package: package(),
      description: description()
    ]
  end

  def application do
    [
      extra_applications: [:crypto]
    ]
  end

  defp deps do
    [
      # hard dependencies
      {:mint, "~> 1.0"},
      {:gpb, "~> 4.0"},
      {:connection, "~> 1.0"},
      # optional dependencies
      {:jason, ">= 0.0.0", optional: true},
      # dev/test utilities
      {:castore, ">= 0.0.0", only: [:dev, :test]},
      {:ex_doc, "~> 0.24", only: :dev, runtime: false},
      # testing suite
      {:credo, "~> 1.5", only: :test},
      {:bless, "~> 1.0", only: :test},
      {:excoveralls, "~> 0.7", only: :test}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support", "test/fixtures"]
  defp elixirc_paths(_), do: ["lib"]

  defp package do
    [
      name: "spear",
      files: ~w(lib src .formatter.exs mix.exs README.md .version),
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => @source_url,
        "Changelog" => @source_url <> "/blob/main/CHANGELOG.md"
      }
    ]
  end

  defp description do
    "A sharp EventStoreDB 20+ client backed by mint"
  end

  defp docs do
    [
      deps: [],
      language: "en",
      formatters: ["html"],
      main: Spear,
      extras: [
        "CHANGELOG.md",
        "guides/writing_events.md",
        "guides/streams.md",
        "guides/link_resolution.md",
        "guides/security.md"
      ],
      groups_for_extras: [
        Guides: Path.wildcard("guides/*.md")
      ],
      groups_for_modules: [
        "Structures and Types": [
          Spear.Acl,
          Spear.Connection.Configuration,
          Spear.Event,
          Spear.ExpectationViolation,
          Spear.Filter.Checkpoint,
          Spear.StreamMetadata,
          Spear.User,
          Spear.ClusterMember,
          Spear.Scavenge,
          Spear.PersistentSubscription,
          Spear.PersistentSubscription.Settings
        ],
        "Record interfaces": [
          Spear.Records.Shared,
          Spear.Records.Streams,
          Spear.Records.Operations,
          Spear.Records.Projections,
          Spear.Records.Persistent,
          Spear.Records.Users,
          Spear.Records.Gossip
        ]
      ],
      groups_for_functions: [
        "Utility Functions": &(&1[:api] == :utils),
        Streams: &(&1[:api] == :streams),
        Users: &(&1[:api] == :users),
        Operations: &(&1[:api] == :operations),
        Projections: &(&1[:api] == :projections),
        "Persistent Subscriptions": &(&1[:api] == :persistent),
        Gossip: &(&1[:api] == :gossip)
      ],
      skip_undefined_reference_warnings_on: [
        "CHANGELOG.md"
      ]
    ]
  end
end
