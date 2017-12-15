defmodule MirrorMirror.Web.DownloadManager do
  use GenStage
  require Logger

  import Ecto.Query

  alias MirrorMirror.{Video, Repo}

  def start_link(_) do
    GenStage.start_link(__MODULE__, [], name: MirrorMirror.Web.DownloadManager)
  end

  def init(_) do
    {:producer, 0}
  end

  def handle_demand(demand, pending_demand) when demand > 0 do
    process_demand(demand + pending_demand)
  end

  defp process_demand(demand) do
    {:ok, {count, (downloads)}} = take(demand)
    {:noreply, downloads || [], demand - count}
  end

  defp take(amount) do
    Repo.transaction fn ->
      query = from v in Video,
                where: v.status == "pending",
                select: v.id,
                order_by: [desc: :inserted_at],
                lock: "FOR UPDATE SKIP LOCKED"

      ids = Repo.all(query)

      Repo.update_all by_ids(ids),
                      [set: [status: "downloading"]],
                      returning: true
    end
  end

  defp by_ids(ids) do
    from v in Video, where: v.id in ^ids
  end

  def handle_cast(enqueue, pending_demand) do
    process_demand(pending_demand)
  end

  def enqueue() do
    GenStage.cast(__MODULE__, :enqueue)
  end
end