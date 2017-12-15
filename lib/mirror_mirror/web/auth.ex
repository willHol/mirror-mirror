defmodule MirrorMirror.Web.Auth do
  use GenServer

  import Process, only: [send_after: 3]

  # The amount to multiply the token expiry by
  @safety_margin 0.9
  @endpoint "https://www.reddit.com/api/v1/access_token"

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    # Initialises the token
    send(self(), :refresh_token)

    {:ok, nil}
  end

  def handle_call(:get_token, _from, token) do
    {:reply, token, token}
  end

  def get_token() do
    GenServer.call(__MODULE__, :get_token)
  end

  def handle_info(:refresh_token, _token) do
    %{"access_token" => token, "expires_in" => time} = request_token()

    # Schedule a refresh
    send_after(self(), :refresh_token, trunc(time * 1000 * @safety_margin))

    {:noreply, token}
  end

  defp request_token() do
    query =
      URI.encode_query(%{
        grant_type: "password",
        username: Application.get_env(:mirror_mirror, :reddit_username),
        password: Application.get_env(:mirror_mirror, :reddit_password)
      })

    opts = [
      {:basic_auth, {Application.get_env(:mirror_mirror, :reddit_client_id),
                   Application.get_env(:mirror_mirror, :reddit_client_secret)}},
      :insecure
    ]

    headers = [
      {"Content-Type", "application/x-www-form-urlencoded"}
    ]

    {:ok, _status, _headers, client} = :hackney.post(@endpoint, headers, query, opts)

    {:ok, body} = :hackney.body(client)

    Poison.decode!(body)
  end
end