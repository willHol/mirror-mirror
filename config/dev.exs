use Mix.Config

config :mirror_mirror, MirrorMirror.Repo,
  database: "mirror_mirror_dev"

config :mirror_mirror,
  output_dir: Path.expand("~/mirror_mirror/data/")