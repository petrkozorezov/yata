defmodule Yata.MixProject do
  use Mix.Project

  def project do
    [
      app: :yata,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Yata, []}
    ]
  end

  defp deps do
    [
      {:grpc, "~> 0.10"},
      {:protobuf, "~> 0.14.1"},
      {:erl_snowflake, "~> 1.1"},
      {:ecto_sql, "~> 3.10"},
      {:ecto_sqlite3, "~> 0.10.0"}
    ]
  end
end
