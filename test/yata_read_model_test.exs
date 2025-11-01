defmodule YataReadModelTest do
  use ExUnit.Case

  alias Yata.{ReadModel, Repo}
  alias Yata.Orders.CommandHandler, as: OrderHandler
  alias Yata.Payments.CommandHandler, as: PaymentHandler
  alias Yata.Store.{OrderDishRecord, OrderRecord, PaymentRecord}

  setup do
    cleanup_db()

    on_exit(fn -> cleanup_db() end)

    :ok
  end

  test "get_order_snapshot returns pending order with payment info" do
    {:ok, order, _} = OrderHandler.create_order()
    {:ok, _order, _} = OrderHandler.add_dish(order.id, "dish-one")
    {:ok, _order, _} = OrderHandler.place(order.id)

    snapshot =
      wait_for(fn ->
        case ReadModel.get_order_snapshot(order.id) do
          {:ok, %ReadModel.OrderSnapshot{order: %{status: :payment_pending}, payment: payment} = snap}
          when not is_nil(payment) ->
            {:ok, snap}

          {:ok, _} ->
            :retry

          other ->
            other
        end
      end)

    assert snapshot.order.id == order.id
    assert snapshot.order.status == :payment_pending
    assert snapshot.order.dishes == ["dish-one"]
    refute snapshot.payment == nil
    assert snapshot.payment.status == :pending
  end

  test "get_order_snapshot reflects payment updates" do
    {:ok, order, _} = OrderHandler.create_order()
    {:ok, _order, _} = OrderHandler.add_dish(order.id, "dish-two")
    {:ok, _order, _} = OrderHandler.place(order.id)

    payment_id =
      wait_for(fn ->
        case ReadModel.get_order_snapshot(order.id) do
          {:ok, %ReadModel.OrderSnapshot{order: %{payment_request_id: payment_id}, payment: payment}}
          when is_binary(payment_id) and payment != nil ->
            {:ok, payment.id}

          {:ok, _} ->
            :retry

          other ->
            other
        end
      end)

    {:ok, _payment, _} = PaymentHandler.mark_succeeded(payment_id, details: %{"tx" => "123"})

    snapshot =
      wait_for(fn ->
        case ReadModel.get_order_snapshot(order.id) do
          {:ok, %ReadModel.OrderSnapshot{order: %{status: :completed}, payment: %{status: :succeeded}} = snap} ->
            {:ok, snap}

          {:ok, _} ->
            :retry

          other ->
            other
        end
      end)

    assert snapshot.payment.id == payment_id
    assert snapshot.payment.status == :succeeded
    assert snapshot.payment.details == %{"tx" => "123"}
    assert snapshot.order.status == :completed
  end

  test "get_order_snapshot returns nil payment for draft order" do
    {:ok, order, _} = OrderHandler.create_order()
    {:ok, snapshot} = ReadModel.get_order_snapshot(order.id)

    assert snapshot.order.status == :draft
    assert snapshot.payment == nil
  end

  test "get_order_snapshot errors for missing order" do
    assert {:error, :not_found} = ReadModel.get_order_snapshot("unknown")
  end

  test "get_order_snapshot validates input" do
    assert {:error, {:invalid_argument, :order_id}} = ReadModel.get_order_snapshot(123)
  end

  defp cleanup_db do
    safe_delete(OrderDishRecord)
    safe_delete(PaymentRecord)
    safe_delete(OrderRecord)
  end

  defp safe_delete(queryable) do
    Repo.delete_all(queryable)
  rescue
    error in Exqlite.Error ->
      if String.contains?(Exception.message(error), "no such table") do
        :ok
      else
        reraise(error, __STACKTRACE__)
      end
  end

  defp wait_for(fun, attempts \\ 30, delay \\ 20)
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
