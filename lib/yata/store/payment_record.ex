defmodule Yata.Store.PaymentRecord do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Yata.Store.OrderRecord

  @primary_key {:id, :string, autogenerate: false}
  schema "payment_requests" do
    field(:status, Ecto.Enum, values: [:pending, :succeeded, :failed])
    field(:details, :map)

    belongs_to(:order, OrderRecord, type: :string)

    timestamps()
  end

  def changeset(payment, attrs) do
    payment
    |> cast(attrs, [:id, :order_id, :status, :details])
    |> validate_required([:id, :order_id, :status])
  end
end
