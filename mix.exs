defmodule Nile.Mixfile do
  use Mix.Project

  def project do
    [app: :nile,
     version: "0.1.0",
     elixir: "~> 1.0",
     description: "Elixir stream extensions",
     package: package,
     deps: deps]
  end

  def application do
    [applications: [:logger]]
  end

  defp deps do
    [{:earmark, "~> 0.1", only: :dev},
     {:ex_doc, "~> 0.10", only: :dev}]
  end

  defp package do
    [files: ["lib", "mix.exs", "README*"],
     maintainers: ["Cameron Bytheway"],
     licenses: ["MIT"],
     links: %{"GitHub" => "https://github.com/camshaft/nile"}]
  end
end
