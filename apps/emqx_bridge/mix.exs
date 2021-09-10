defmodule EMQXBridge.MixProject do
  use Mix.Project

  def project do
    [
      app: :emqx_bridge,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "EMQ X Bridge"
    ]
  end

  def application do
    [
      registered: [],
      mod: {:emqx_bridge_app, []},
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:emqx, in_umbrella: true},
			{:emqx_connector, in_umbrella: true}
    ]
  end
end
