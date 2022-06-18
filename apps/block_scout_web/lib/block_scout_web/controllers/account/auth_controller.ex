defmodule BlockScoutWeb.Account.AuthController do
  use BlockScoutWeb, :controller

  alias BlockScoutWeb.Guardian

  plug(Ueberauth)

  def logout(conn, _params) do
    conn
    |> configure_session(drop: true)
    |> redirect(to: root())
  end

  def profile(conn, _params),
    do: conn |> get_session(:current_user) |> do_profile(conn)

  defp do_profile(nil, conn),
    do: redirect(conn, to: root())

  defp do_profile(%{} = user, conn),
    do: render(conn, :profile, user: user)

  defp debug(value, key) do
    require Logger
    Logger.configure(truncate: :infinity)
    Logger.info(key)
    Logger.info(Kernel.inspect(value, limit: :infinity, printable_limit: :infinity))
    value
  end

  def callback(%{assigns: %{ueberauth_failure: _fails}} = conn, _params) do
    conn
    |> put_flash(:error, "Failed to authenticate.")
    |> redirect(to: root())
  end

  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, _params) do
    debug(conn, "conn")
    debug(auth, "auth")

    case UserFromAuth.find_or_create(auth) do
      {:ok, user} ->
        conn
        |> put_session(:current_user, user)
        |> redirect(to: root())

      {:error, reason} ->
        conn
        |> put_flash(:error, reason)
        |> redirect(to: root())
    end
  end

  def api_callback(%{assigns: %{ueberauth_failure: _fails}} = conn, _params) do
    send_resp(conn, 200, "Failed to authenticate")
  end

  def api_callback(%{assigns: %{ueberauth_auth: auth}} = conn, _params) do
    case UserFromAuth.find_or_create(auth, true) |> debug("find or create") do
      {:ok, user} ->
        {:ok, token, _} = Guardian.encode_and_sign(user)

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, Jason.encode!(%{"auth_token" => token}))

      {:error, _reason} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, Jason.encode!(%{"message" => "Failed to authenticate."}))
    end
  end

  # for importing in other controllers
  def authenticate!(conn) do
    current_user(conn) || redirect(conn, to: root())
  end

  def current_user(%{private: %{plug_session: %{"current_user" => _}}} = conn),
    do: get_session(conn, :current_user)

  def current_user(_), do: nil

  defp root do
    System.get_env("NETWORK_PATH") || "/"
  end
end
