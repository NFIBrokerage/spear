defmodule Spear.MixProject do
  use Mix.Project

  @source_url "https://github.com/NFIBrokerage/spear"

  def project do
    [
      app: :spear,
      version: "0.1.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
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
      {:mint, "~> 1.0"},
      {:protobuf, "~> 0.7"},
      {:jason, ">= 0.0.0", optional: true},
      {:castore, ">= 0.0.0", only: [:dev, :test]},
      {:ex_doc, "~> 0.24", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      name: "spear",
      files: ~w(lib .formatter.exs mix.exs README.md .version),
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => @source_url,
        "Changelog" => @source_url <> "/blob/main/CHANGELOG.md"
      }
    ]
  end

  defp description do
    "A sharp EventStore 20+ client backed by mint"
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
        "guides/link_resolution.md"
      ],
      groups_for_extras: [
        Guides: Path.wildcard("guides/*.md")
      ],
      skip_undefined_reference_warnings_on: [
        "CHANGELOG.md"
      ]
    ]
  end
end
