defmodule Yata.ReadModel do
  @moduledoc """
  Provides query access to order aggregates with optional payment snapshot.
  """

  alias Yata.{Order, PaymentRequest, Store}

  defmodule OrderSnapshot do
    @moduledoc false
    @enforce_keys [:order]
    defstruct [:order, :payment]

    @type t :: %__MODULE__{
            order: Order.t(),
            payment: PaymentRequest.t() | nil
          }
  end

  @type order_id :: Order.id()
  @type result :: {:ok, OrderSnapshot.t()} | {:error, term()}

  @spec get_order_snapshot(order_id()) :: result()
  def get_order_snapshot(order_id) when is_binary(order_id) do
    with {:ok, %Order{} = order} <- Store.fetch_order(order_id),
         {:ok, payment} <- maybe_fetch_payment(order.payment_request_id) do
      {:ok, %OrderSnapshot{order: order, payment: payment}}
    end
  end

  def get_order_snapshot(_), do: {:error, {:invalid_argument, :order_id}}

  defp maybe_fetch_payment(nil), do: {:ok, nil}

  defp maybe_fetch_payment(payment_id) when is_binary(payment_id) do
    case Store.fetch_payment(payment_id) do
      {:ok, %PaymentRequest{} = payment} -> {:ok, payment}
      {:error, :not_found} -> {:ok, nil}
      other -> other
    end
  end

  defp maybe_fetch_payment(_), do: {:error, {:invalid_argument, :payment_id}}
end
