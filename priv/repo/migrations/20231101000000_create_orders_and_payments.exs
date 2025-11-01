defmodule Yata.Repo.Migrations.CreateOrdersAndPayments do
  use Ecto.Migration

  def change do
    create table(:orders, primary_key: false) do
      add :id, :string, primary_key: true
      add :status, :string, null: false
      add :payment_request_id, :string

      timestamps()
    end

    create table(:order_dishes) do
      add :order_id, references(:orders, type: :string, on_delete: :delete_all), null: false
      add :dish_id, :string, null: false
      add :position, :integer, null: false

      timestamps(updated_at: false)
    end

    create unique_index(:order_dishes, [:order_id, :dish_id])
    create index(:order_dishes, [:order_id, :position])

    create table(:payment_requests, primary_key: false) do
      add :id, :string, primary_key: true
      add :order_id, references(:orders, type: :string, on_delete: :delete_all), null: false
      add :status, :string, null: false
      add :details, :map

      timestamps()
    end

    create index(:payment_requests, [:order_id])
  end
end
