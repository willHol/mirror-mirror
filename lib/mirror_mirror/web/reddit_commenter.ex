defmodule MirrorMirror.Web.RedditCommenter do
  use GenServer
  require Logger

  import Process, only: [send_after: 3]
  import Ecto.Query

  alias MirrorMirror.{Repo, Video}
  alias MirrorMirror.Web.Auth

  alias Ecto.Multi

  @endpoint "https://www.oauth.reddit.com/api/comment"

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    schedule_commenting()
    {:ok, []}
  end

  def handle_info(:place_comments, state) do
    unplaced = unplaced_comments()

    # 1 comment for each video
    Enum.each(unplaced, &make_comment/1)

    schedule_commenting()

    {:noreply, state}
  end

  defp make_comment({id, parent, links}) do
    Logger.info fn ->
      "Placing comment for #{parent}"
    end


    query =
      URI.encode_query(%{api_type: :json,
                         text: comment_text(links),
                         thing_id: parent})

    opts = [:insecure, {:follow_redirect, true}, {:max_redirect, 5}]

    headers = [
      {"Authorization", "bearer " <> Auth.get_token()},
      {"User-Agent", "mirrormirror-bot"},
      {"Content-Type", "application/x-www-form-urlencoded"}
    ]

    {:ok, _status, _headers, client} = :hackney.post(@endpoint, headers, query, opts)

    {:ok, body} = :hackney.body(client)

    # %{"json" => %{"data" => %{"things" => [%{"data" => %{"id" => comment_id}}}}} =
    #   Poison.decode!(body)

    # Video
    # |> Repo.get(id)
    # |> Video.changeset(%{comment_id: comment_id})
    # |> Repo.update!
  end

  defp comment_text(links) do
    links_text =
      links
      |> Enum.with_index()
      |> Enum.map(fn {link, i} -> "\n[#{i}](#{link})" end)
      |> Enum.join()

    "**Mirrors**\n" <> links_text
  end

  # Returns a list of {fullname, [mirror1, mirror2]}
  defp unplaced_comments() do
    query =
      from v in Video,
        where: v.status == "uploaded" and is_nil(v.comment_id),
        order_by: [v.updated_at],
        select: {v.id, v.op_full, v.mirrors}

    Repo.all(query)
  end

  defp schedule_commenting() do
    send_after(self(), :place_comments, 30 * 1000)
  end
end