defmodule Spear.MixProject do
  use Mix.Project

  def project do
    [
      app: :spear,
      version: "0.1.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs()
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

  defp docs do
    [
      main: "Spear"
    ]
  end
end
