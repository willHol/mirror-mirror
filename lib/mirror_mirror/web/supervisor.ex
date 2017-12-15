defmodule MirrorMirror.Web.Supervisor do
  use Supervisor

  def start_link(_) do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_arg) do
    children = [
      MirrorMirror.Web.DownloadManager,
      MirrorMirror.Web.UploadManager,
      MirrorMirror.Web.Auth,
      MirrorMirror.Web.RedditCommenter
    ]

    downloaders =
      for i <- 1..System.schedulers_online()*2 do
        Supervisor.child_spec({MirrorMirror.Web.Downloader, []}, id: i)
      end

    uploaders =
      for i <- (System.schedulers_online()*2+1)..System.schedulers_online()*4 do
        Supervisor.child_spec({MirrorMirror.Web.Uploader, []}, id: i)
      end

    subreddit_watchers =
      :mirror_mirror
      |> Application.get_env(:subreddits)
      |> Enum.map(fn sub ->
           Supervisor.child_spec({MirrorMirror.Web.RedditWatcher, [sub]}, id: sub)
         end)

    combined_children = children ++
                        subreddit_watchers ++
                        downloaders ++
                        uploaders

    Supervisor.init(combined_children, strategy: :one_for_one)
  end
end