defmodule Yata.Store.OrderDishRecord do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Yata.Store.OrderRecord

  schema "order_dishes" do
    field(:dish_id, :string)
    field(:position, :integer)

    belongs_to(:order, OrderRecord, type: :string)

    timestamps(updated_at: false)
  end

  def changeset(dish, attrs) do
    dish
    |> cast(attrs, [:order_id, :dish_id, :position])
    |> validate_required([:order_id, :dish_id, :position])
  end
end
