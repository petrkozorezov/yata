ExUnit.start()

{:ok, _, _} =
  Ecto.Migrator.with_repo(Yata.Repo, fn repo ->
    Ecto.Migrator.run(repo, Path.join(["priv", "repo", "migrations"]), :up, all: true)
  end)

{:ok, _} = Application.ensure_all_started(:yata)
