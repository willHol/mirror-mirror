use Mix.Config

config :logger,
  backends: [:console],
  compile_time_purge_level: :info,
  level: :info

config :mirror_mirror, MirrorMirror.Repo,
  adapter: Ecto.Adapters.Postgres,
  hostname: "localhost",
  username: "postgres",
  password: "postgres"

config :mirror_mirror, ecto_repos: [MirrorMirror.Repo]

config :mirror_mirror,
  subreddits: ["MMA", "sports"],
  env: Mix.env,
  streamable_email: "",
  streamable_password: "",
  reddit_username: "mirrormirror-bot",
  reddit_password: System.get_env("REDDIT_PASSWORD"),
  reddit_client_id: "",
  reddit_client_secret: System.get_env("REDDIT_SECRET")


import_config "#{Mix.env}.exs"