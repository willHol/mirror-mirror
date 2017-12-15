defmodule MirrorMirror.VideoStreamError do
  defexception [:message]
end

defmodule MirrorMirror.Video do
  @moduledoc """
  The Video struct and associated functions.
  """
  
  use Ecto.Schema

  import Ecto.Changeset
  require Logger

  alias MirrorMirror.{Video, Repo, VideoStreamError}

  schema "videos" do
    field :path, :string
    field :source_url_wq, :string
    field :url, :string
    field :mirrors, {:array, :string}
    field :op_full, :string
    field :comment_id, :string
    field :status, :string, default: "pending"

    timestamps()
  end

  @possible_status ~w(pending downloaded downloading uploaded uploading
                      failed_download failed_upload)

  def changeset(%Video{} = video, attrs) do
    video
    |> cast(attrs, [:path, :op_full, :source_url_wq, :status, :mirrors])
    |> unique_constraint(:url)
    |> decompose_url()
    |> validate_inclusion(:status, @possible_status)
  end

  defp decompose_url(%Ecto.Changeset{changes: %{source_url_wq: url}} = changeset) do
    %URI{host: host, path: path} = URI.parse(url)
    put_change(changeset, :url, host <> path)
  end

  defp decompose_url(changeset), do: changeset

  def create_video(attrs \\ %{}) do
    %Video{}
    |> changeset(attrs)
    |> Repo.insert()
  end

  def upload(%Video{status: "uploaded"}), do: {:error, :already_downloaded}

  def upload(%Video{path: path} = video, url \\ "https://api.streamable.com/upload") do
    # Uploads the file as a multipart request
    {:ok, _status, headers, client} = :hackney.request(
      :post, url, [], {:multipart, [{:file, path}]},
      [
        {:basic_auth, {Application.get_env(:mirror_mirror, :streamable_email),
                       Application.get_env(:mirror_mirror, :streamable_password)}},
        {:recv_timeout, :infinity},
        {:connect_timeout, 120000},
        {:timeout, 120000},
        {:recv_timeout, 360000},
        :insecure
    ])

    # Json encoded response
    {:ok, body} = :hackney.body(client)
    {:ok, %{"shortcode" => code}} = Poison.decode(body)

    updated_video =
      video
      |> changeset(%{status: "uploaded",
                     mirrors: video.mirrors ++ ["https://streamable.com/#{code}"]})
      |> Repo.update()
  rescue
    _ ->
      {:error, :idk}
  end

  @doc """
  Streams the video identified by the URI to the filesystem.
  """
  def download(%Video{status: "downloaded"} = video, url, file_path) do
   {:error, :already_downloaded}
  end

  def download(%Video{source_url_wq: url_wq, url: url} = video, file_path) do
    # Custom resource based on hackney streaming
    source =
      Stream.resource(fn -> init_download(url_wq) end,
                      &continue_download/1,
                      &after_download/1)

    sink = File.stream!(file_path, [:write], :bytes)

    # Stream from the source into the sink
    source
    |> Stream.into(sink)
    |> Stream.run()

    changes = %{
      path: file_path,
      status: "downloaded"
    }

    updated_video =
      video
      |> changeset(changes)
      |> Repo.update!()

    {:ok, updated_video}
  rescue
    e in VideoStreamError ->
      {:error, :download_failed}
    e in Ecto.InvalidChangesetError ->
      {:error, :update_failed}
  end

  defp init_download(url) do
    Logger.info fn -> "Initialising download from #{url}" end

    {:ok, _status, headers, client} = :hackney.get(url, [], "", [:insecure])

    total_size =
      case keyword_get(headers, "Content-Length") do
        nil -> "N/A"
        <<total_size::binary>> -> total_size
      end

    {url, client, total_size, 0}
  end

  defp continue_download({url, client, total_size, size}) do
    case :hackney.stream_body(client) do
      {:ok, data} ->
        Logger.debug fn ->
          "Downloaded (#{size}/#{total_size}) bits from #{url}"
        end

        {[data], {url, client, total_size, size + byte_size(data)}}
      :done ->
        {:halt, {url, client}}
      {:error, reason} ->
        {:halt, {:error, url, reason}}
    end
  end

  defp continue_download({:error, url, reason}) do
    {:halt, {:error, url, reason}}
  end

  defp after_download({:error, url, reason}) do
    Logger.error fn -> "Download from #{url} failed: \n#{inspect reason}" end

    raise VideoStreamError, message: reason
  end

  defp after_download({url, _client}) do
    Logger.info fn -> "Download from #{url} completed" end
  end

  defp keyword_get(list, string) do
    res =
      Enum.find list, fn {k, _v} ->
        k === string
      end

    case res do
      {_k, v} -> v
      nil -> nil
    end
  end
end