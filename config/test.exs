use Mix.Config

config :mirror_mirror, MirrorMirror.Repo,
  adapter: Ecto.Adapters.Postgres,
  database: "mirror_mirror_test"