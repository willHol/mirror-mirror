defmodule MirrorMirror.Repo do
  use Ecto.Repo, otp_app: :mirror_mirror

  @doc """
  Configures the db password at runtime
  """
  def init(_type, config) do
    db_password = System.get_env("DATABASE_PASSWORD")

    runtime_conf = if db_password do
                     config |> Keyword.put(:password, db_password)
                   else
                     config
                   end

    {:ok, runtime_conf}
  end
end