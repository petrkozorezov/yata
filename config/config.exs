import Config

config :yata, Yata.Repo,
  database: "yata.sqlite3",
  pool_size: 5

config :yata,
  ecto_repos: [Yata.Repo],
  event_bus: Yata.EventBus.InMemory
