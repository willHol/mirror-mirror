defmodule MirrorMirror.Mixfile do
  use Mix.Project

  def project do
    [
      app: :mirror_mirror,
      version: "0.1.0",
      elixir: "~> 1.5",
      start_permanent: Mix.env == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {MirrorMirror.Application, []}
    ]
  end

  defp deps do
    [
      {:hackney, "~> 1.10"},
      {:ecto, "~> 2.2"},
      {:postgrex, ">= 0.0.0"},
      {:poison, "~> 3.1"},
      {:floki, "~> 0.18"},
      {:gen_stage, "~> 0.12"}
    ]
  end
end
