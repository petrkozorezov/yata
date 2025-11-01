defmodule Yata.Orders.CommandHandler do
  @moduledoc """
  Executes commands against the order aggregate and persists the results.
  """

  alias Yata.{EventBus, Order, Store}

  @type order_id :: Order.id()
  @type dish_id :: Order.dish_id()
  @type result :: {:ok, Order.t(), [Order.Event.t()]} | {:error, term()}

  @spec create_order(Keyword.t()) :: result()
  def create_order(opts \\ []) do
    with {:ok, order, events} <- Order.create(opts),
         :ok <- Store.save_order(order),
         :ok <- EventBus.publish(events) do
      {:ok, order, events}
    end
  end

  @spec add_dish(order_id(), dish_id()) :: result()
  def add_dish(order_id, dish_id) do
    with {:ok, order} <- Store.fetch_order(order_id),
         {:ok, updated, events} <- Order.add_dish(order, dish_id),
         :ok <- Store.save_order(updated),
         :ok <- EventBus.publish(events) do
      {:ok, updated, events}
    end
  end

  @spec remove_dish(order_id(), dish_id()) :: result()
  def remove_dish(order_id, dish_id) do
    with {:ok, order} <- Store.fetch_order(order_id),
         {:ok, updated, events} <- Order.remove_dish(order, dish_id),
         :ok <- Store.save_order(updated),
         :ok <- EventBus.publish(events) do
      {:ok, updated, events}
    end
  end

  @spec place(order_id()) :: result()
  def place(order_id) do
    with {:ok, order} <- Store.fetch_order(order_id),
         {:ok, updated, events} <- Order.place(order),
         :ok <- Store.save_order(updated),
         :ok <- EventBus.publish(events) do
      {:ok, updated, events}
    end
  end

  @spec mark_payment_pending(order_id(), Yata.PaymentRequest.id()) :: result()
  def mark_payment_pending(order_id, payment_id) do
    with {:ok, order} <- Store.fetch_order(order_id),
         {:ok, updated, events} <- Order.mark_payment_pending(order, payment_id),
         :ok <- Store.save_order(updated),
         :ok <- EventBus.publish(events) do
      {:ok, updated, events}
    end
  end

  @spec complete(order_id()) :: result()
  def complete(order_id) do
    with {:ok, order} <- Store.fetch_order(order_id),
         {:ok, updated, events} <- Order.complete(order),
         :ok <- Store.save_order(updated),
         :ok <- EventBus.publish(events) do
      {:ok, updated, events}
    end
  end

  @spec cancel(order_id(), keyword()) :: result()
  def cancel(order_id, opts \\ []) do
    with {:ok, order} <- Store.fetch_order(order_id),
         {:ok, updated, events} <- Order.cancel(order, opts),
         :ok <- Store.save_order(updated),
         :ok <- EventBus.publish(events) do
      {:ok, updated, events}
    end
  end
end
