defmodule EctoMorph.MixProject do
  use Mix.Project

  def project do
    [
      name: "EctoMorph",
      app: :ecto_morph,
      description: description(),
      version: "0.1.23",
      package: package(),
      elixirc_paths: elixirc_paths(Mix.env()),
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      source_url: "https://github.com/Adzz/ecto_morph",
      deps: deps()
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(:dev), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def application, do: [extra_applications: [:logger]]

  defp deps do
    [
      {:ecto, ">= 3.0.3"},
      {:ex_doc, "~> 0.19", only: :docs, runtime: false}
    ]
  end

  defp description(), do: "A utility library for Ecto"

  defp package() do
    [
      licenses: ["Apache 2.0"],
      links: %{"GitHub" => "https://github.com/Adzz/ecto_morph"}
    ]
  end
end
