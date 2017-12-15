defmodule MirrorMirror.Web.Downloader do
  use GenStage
  require Logger

  alias MirrorMirror.Web.{UploadManager, DownloadManager}
  alias MirrorMirror.Video
  alias Ecto.Changeset

  @sources [".mp4", ".webm", ".mkv"]

  def start_link(_) do
    GenStage.start_link(__MODULE__, [])
  end

  def init(_) do
    {:consumer, 0, subscribe_to: [{DownloadManager, max_demand: 1}]}
  end

  def handle_events([video], _from, count) do
    case download_video(video) do
      :ok -> {:noreply, [], count + 1}
      :error -> {:noreply, [], count}
    end
  end

  defp download_video(video, retries \\ 2)
  defp download_video(video, 0) do
    Logger.error fn ->
      "Max retries exceeded for #{video.url}, abandoning download."
    end

    :error
  end
  defp download_video(%Video{url: url} = video, retries) do
    path = output_file(url)

    case Video.download(video, path) do
      {:ok, _video} ->
        UploadManager.upload(path)
      {:error, _reason} ->
        download_video(video, retries - 1)
    end

    :ok
  end

  defp output_file(url) do
    Path.join([
      Application.get_env(:mirror_mirror, :output_dir),
      Base.url_encode64(:crypto.strong_rand_bytes(6), padding: false) <> get_extension(url)
    ])
  end

  defp get_extension(url) do
    Enum.find(@sources, fn source ->
      source in @sources
    end)
  end
end