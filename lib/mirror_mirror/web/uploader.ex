defmodule MirrorMirror.Web.Uploader do
  use GenStage
  require Logger

  alias MirrorMirror.Web.{UploadManager, DownloadManager, RedditCommentor}
  alias MirrorMirror.Video
  alias Ecto.Changeset

  @sources [".mp4", ".webm", ".mkv"]

  def start_link(_) do
    GenStage.start_link(__MODULE__, [])
  end

  def init(_) do
    {:consumer, 0, subscribe_to: [{UploadManager, max_demand: 1}]}
  end

  def handle_events([url], _from, count) do
    case upload_video(url) do
      :ok -> {:noreply, [], count + 1}
      :error -> {:noreply, [], count}
    end
  end

  defp upload_video(video, retries \\ 2)
  defp upload_video(video, 0) do
    Logger.error fn ->
      "Max retries exceeded for #{video.url}, abandoning download."
    end

    :error
  end
  defp upload_video(%Video{} = video, retries) do
    case Video.upload(video) do
      {:ok, video} ->
        Logger.info fn ->
          "Successfully uploaded to #{video.mirrors}"
        end
      {:error, video} ->
        upload_video(video, retries - 1)
    end

    :ok
  end
end