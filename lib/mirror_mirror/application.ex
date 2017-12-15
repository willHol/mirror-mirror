defmodule MirrorMirror.Application do
  @moduledoc false
  use Application

  def start(_type, _args) do
    children = [
      MirrorMirror.Repo,
      MirrorMirror.Web.Supervisor
    ]

    opts = [strategy: :one_for_one, name: MirrorMirror.Supervisor]

    # Ensure the output dir exists
    :ok = File.mkdir_p(Application.get_env(:mirror_mirror, :output_dir))

    Supervisor.start_link(children, opts)
  end
end
