defmodule Yata.Repo do
  use Ecto.Repo,
    otp_app: :yata,
    adapter: Ecto.Adapters.SQLite3
end
