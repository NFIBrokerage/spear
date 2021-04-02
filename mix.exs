defmodule Spear.MixProject do
  use Mix.Project

  def project do
    [
      app: :spear,
      version: "0.1.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:mint, "~> 1.0"},
      {:protobuf, "~> 0.7"},
      {:castore, "~> 0.0", only: [:dev, :test]}
    ]
  end
end
