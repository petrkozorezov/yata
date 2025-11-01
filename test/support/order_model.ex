defmodule Yata.TestSupport.OrderModel do
  @moduledoc false

  alias Yata.Order
  import ExUnit.Assertions

  @type t :: %{
          status: Order.status(),
          dishes: [Order.dish_id()],
          payment_request_id: Order.id() | nil
        }

  @spec new(Order.t()) :: t()
  def new(%Order{} = order) do
    %{status: order.status, dishes: order.dishes, payment_request_id: order.payment_request_id}
  end

  @spec assert_equivalent(Order.t(), t()) :: :ok
  def assert_equivalent(%Order{} = order, %{status: status, dishes: dishes, payment_request_id: payment_id}) do
    assert order.status == status
    assert order.dishes == dishes
    assert order.payment_request_id == payment_id
    :ok
  end

  @spec apply(t(), term()) :: {:ok, t()} | {:error, term()}
  def apply(model, {:add, dish_id}), do: add_dish(model, dish_id)
  def apply(model, {:remove, dish_id}), do: remove_dish(model, dish_id)
  def apply(model, :place), do: place(model)
  def apply(model, {:mark_pending, payment_id}), do: mark_pending(model, payment_id)
  def apply(model, :complete), do: complete(model)
  def apply(model, {:cancel, _reason}), do: cancel(model)
  def apply(model, :noop), do: {:ok, model}

  defp add_dish(%{status: :draft, dishes: dishes} = model, dish_id) do
    if dish_id in dishes do
      {:ok, model}
    else
      {:ok, %{model | dishes: dishes ++ [dish_id]}}
    end
  end

  defp add_dish(%{status: status}, _dish_id),
    do: {:error, {:unexpected_status, status, :add_dish}}

  defp remove_dish(%{status: :draft, dishes: dishes} = model, dish_id) do
    if dish_id in dishes do
      {:ok, %{model | dishes: List.delete(dishes, dish_id)}}
    else
      {:error, {:dish_not_found, dish_id}}
    end
  end

  defp remove_dish(%{status: status}, _dish_id),
    do: {:error, {:unexpected_status, status, :remove_dish}}

  defp place(%{status: :draft, dishes: []}),
    do: {:error, :empty_order}

  defp place(%{status: :draft} = model),
    do: {:ok, %{model | status: :placed}}

  defp place(%{status: status}),
    do: {:error, {:unexpected_status, status, :place_order}}

  defp mark_pending(%{status: :placed} = model, payment_id),
    do: {:ok, %{model | status: :payment_pending, payment_request_id: payment_id}}

  defp mark_pending(%{status: status}, _payment_id),
    do: {:error, {:unexpected_status, status, :mark_payment_pending}}

  defp complete(%{status: :payment_pending} = model),
    do: {:ok, %{model | status: :completed}}

  defp complete(%{status: status}),
    do: {:error, {:unexpected_status, status, :complete_order}}

  defp cancel(%{status: status} = model)
       when status in [:placed, :payment_pending],
       do: {:ok, %{model | status: :cancelled}}

  defp cancel(%{status: status}),
    do: {:error, {:unexpected_status, status, :cancel_order}}
end
