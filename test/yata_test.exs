defmodule YataTest do
  use ExUnit.Case

  alias Yata.{Order, PaymentRequest, Store}
  alias Yata.Orders.CommandHandler, as: OrderHandler

  test "creates order and stores it" do
    {:ok, order, events} = OrderHandler.create_order()

    assert order.status == :draft
    assert Enum.any?(events, &(&1.name == :order_created))
    assert {:ok, ^order} = Store.fetch_order(order.id)
  end

  test "places order and triggers payment process asynchronously" do
    {:ok, order, _} = OrderHandler.create_order()
    {:ok, order, _} = OrderHandler.add_dish(order.id, "dish-42")
    {:ok, _order, _} = OrderHandler.place(order.id)

    payment_id =
      wait_for(fn ->
        case Store.fetch_order(order.id) do
          {:ok, %Order{status: :payment_pending, payment_request_id: payment_id}}
          when is_binary(payment_id) ->
            {:ok, payment_id}

          {:ok, _order} ->
            :retry

          {:error, :not_found} ->
            :retry
        end
      end)

    assert {:ok, %PaymentRequest{status: :pending}} = Store.fetch_payment(payment_id)
  end

  defp wait_for(fun, attempts \\ 20, delay \\ 25)
  defp wait_for(_fun, 0, _delay), do: flunk("timed out waiting for condition")

  defp wait_for(fun, attempts, delay) do
    case fun.() do
      {:ok, value} ->
        value

      :retry ->
        Process.sleep(delay)
        wait_for(fun, attempts - 1, delay)

      {:error, _} ->
        Process.sleep(delay)
        wait_for(fun, attempts - 1, delay)
    end
  end
end
