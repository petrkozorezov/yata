defmodule Yata.Payments.CommandHandler do
  @moduledoc """
  Executes commands against the payment request aggregate.
  """

  alias Yata.{EventBus, PaymentRequest, Store}

  @type payment_id :: PaymentRequest.id()
  @type result :: {:ok, PaymentRequest.t(), [PaymentRequest.Event.t()]} | {:error, term()}

  @spec create_request(Yata.Order.id(), keyword()) :: result()
  def create_request(order_id, opts \\ []) do
    with {:ok, request, events} <- PaymentRequest.create(order_id, opts),
         :ok <- Store.save_payment(request),
         :ok <- EventBus.publish(events) do
      {:ok, request, events}
    end
  end

  @spec mark_succeeded(payment_id(), keyword()) :: result()
  def mark_succeeded(payment_id, opts \\ []) do
    with {:ok, request} <- Store.fetch_payment(payment_id),
         {:ok, updated, events} <- PaymentRequest.mark_succeeded(request, opts),
         :ok <- Store.save_payment(updated),
         :ok <- EventBus.publish(events) do
      {:ok, updated, events}
    end
  end

  @spec mark_failed(payment_id(), keyword()) :: result()
  def mark_failed(payment_id, opts \\ []) do
    with {:ok, request} <- Store.fetch_payment(payment_id),
         {:ok, updated, events} <- PaymentRequest.mark_failed(request, opts),
         :ok <- Store.save_payment(updated),
         :ok <- EventBus.publish(events) do
      {:ok, updated, events}
    end
  end
end
