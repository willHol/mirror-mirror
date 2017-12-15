defmodule MirrorMirror.Repo.Migrations.CreateVideos do
  use Ecto.Migration

  def change do
    create table(:videos) do
      add :path, :string
      add :source_url_wq, :string
      add :url, :string
      add :mirrors, {:array, :string}, default: []
      add :status, :string

      add :op_full, :string
      add :comment_id, :string

      timestamps()
    end

    create unique_index(:videos, [:url])
  end
end
