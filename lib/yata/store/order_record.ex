defmodule Yata.Store.OrderRecord do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Yata.Store.OrderDishRecord

  @primary_key {:id, :string, autogenerate: false}
  schema "orders" do
    field(:status, Ecto.Enum, values: [:draft, :placed, :payment_pending, :completed, :cancelled])
    field(:payment_request_id, :string)

    has_many(:dishes, OrderDishRecord, foreign_key: :order_id)

    timestamps()
  end

  def changeset(order, attrs) do
    order
    |> cast(attrs, [:id, :status, :payment_request_id])
    |> validate_required([:id, :status])
  end
end
