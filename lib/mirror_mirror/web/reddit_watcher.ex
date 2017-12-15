defmodule MirrorMirror.Web.RedditWatcher do
  use GenServer
  require Logger
  import Process, only: [send_after: 3]

  alias MirrorMirror.Web.DownloadManager
  alias MirrorMirror.Video

  @preferred_sources ["mp4", "webm"]

  def start_link([sub]) do
    GenServer.start_link(__MODULE__, [sub])
  end

  def init([sub]) do
    schedule_work()
    {:ok, %{sub: sub, last_id: ""}}
  end

  def get_recent_posts(sub, limit \\ 50) do
    url = "https://www.reddit.com/r/#{sub}/new.json?sort=new&kind=t3&raw_json=1&limit=#{limit}"

    with {:ok, _status, headers, client} <- :hackney.get(url, [], "", [:insecure]),
         {:ok, body}                     <- :hackney.body(client),
         {:ok, %{"data" =>
                %{"children" => posts}}} <- Poison.decode(body)
         do
           Enum.map(posts, &unpack_data/1)
         else
          {:error, _} -> []
         end
  end

  defp unpack_data(%{} = map) do
    map["data"]
  end

  defp unseen_posts(posts, last_id) do
    posts -- Enum.drop_while(posts, &(&1["id"] !== last_id))
  end

  def handle_info(:work, %{sub: sub, last_id: last_id} = state) do
    posts =
      sub
      |> get_recent_posts()
      |> unseen_posts(last_id)

    new_last_id = with new when new != nil <- Enum.at(posts, 0)["id"]
                  do
                    new
                  else
                    _ -> last_id
                  end

    sources =
      posts
      |> get_sources()
      |> Enum.map(&process_urls/1)
      |> Enum.each(&persist_record/1)

    # Tell the DownloadManager that there are items to process
    queue_download_requests()

    schedule_work()

    {:noreply, %{state | last_id: new_last_id}}
  end

  defp get_sources(posts) do
    Enum.reduce(posts, [], fn %{"url" => url} = post, sources ->
      with {:ok, _status, headers, client} <- :hackney.get(url, [], "", [:insecure]),
           {:ok, html} <- :hackney.body(client)
          do
            if String.valid?(html) && Floki.find(html, "video > source") !== [] do
              Logger.debug fn -> "Crawling #{url}" end

              source =
                html
                |> Floki.find("video > source")
                |> Floki.attribute("src")
                |> get_preferred_source()

              if source do
                [{make_fullname(post), source} | sources]
              else
                sources
              end
            else
              # Not a valid string, raw binary, likely an image or video
              # direct link
              sources
            end
          else
            _ -> sources
          end
    end)
  end

  defp make_fullname(post) do
    "t3_" <> post["id"]
  end

  defp persist_record({fullname, url}) do
    case Video.create_video(%{source_url_wq: url, op_full: fullname}) do
      {:ok, _video} ->
        :ok
      {:error, _reason} ->
        Logger.error fn ->
          "Failed to write #{url} record to db."
      end
    end
  end

  defp process_urls({fullname, url}) do
    cond do
      url =~ ~r(^//) -> {fullname, String.replace(url, ~r(^//), "https://")}
      true -> {fullname, url}
    end
  end

  defp queue_download_requests() do
    DownloadManager.enqueue()
  end

  defp get_preferred_source(sources) do
    Enum.find(sources, fn source ->
      Enum.any?(@preferred_sources, &(source =~ &1))
    end)
  end

  defp schedule_work() do
    send_after(self(), :work, 30 * 1000)
  end
end