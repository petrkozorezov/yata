defmodule YataEctoStoreTest do
  use ExUnit.Case

  import Ecto.Query

  alias Yata.{Repo, Order, PaymentRequest, Store}
  alias Yata.Orders.CommandHandler, as: OrderHandler
  alias Yata.Payments.CommandHandler, as: PaymentHandler
  alias Yata.Store.{OrderDishRecord, OrderRecord, PaymentRecord}

  setup do
    cleanup_db()

    on_exit(fn ->
      cleanup_db()
    end)

    :ok
  end

  test "persists order and payment through Ecto repositories" do
    {:ok, order, _} = OrderHandler.create_order()
    {:ok, order, _} = OrderHandler.add_dish(order.id, "dish-ecto")
    {:ok, _order, _} = OrderHandler.place(order.id)

    pending_order =
      wait_for(fn ->
        case Store.fetch_order(order.id) do
          {:ok, %Order{status: :payment_pending} = record} -> {:ok, record}
          {:ok, %Order{}} -> :retry
          {:error, :not_found} -> :retry
          other -> other
        end
      end)

    dishes =
      Repo.all(from(d in OrderDishRecord, where: d.order_id == ^order.id, order_by: d.position))
      |> Enum.map(& &1.dish_id)

    assert dishes == ["dish-ecto"]

    payment_record =
      wait_for(fn ->
        case Repo.one(from(p in PaymentRecord, where: p.order_id == ^order.id, limit: 1)) do
          nil -> :retry
          record -> {:ok, record}
        end
      end)

    {:ok, _payment, _} =
      PaymentHandler.mark_succeeded(payment_record.id, details: %{"tx" => "ok"})

    completed_order =
      wait_for(fn ->
        case Store.fetch_order(order.id) do
          {:ok, %Order{status: :completed} = record} -> {:ok, record}
          {:ok, %Order{}} -> :retry
          other -> other
        end
      end)

    persisted_payment = Repo.get!(PaymentRecord, payment_record.id)
    assert persisted_payment.status == :succeeded
    assert persisted_payment.details == %{"tx" => "ok"}

    assert completed_order.payment_request_id == payment_record.id
    assert pending_order.payment_request_id == payment_record.id
  end

  describe "store validations" do
    test "fetch_order/1 rejects non-binary id" do
      assert {:error, {:invalid_argument, :order_id}} = Store.fetch_order(123)
    end

    test "fetch_payment/1 rejects non-binary id" do
      assert {:error, {:invalid_argument, :payment_id}} = Store.fetch_payment(:atom)
    end

    test "save_order/1 returns validation error for invalid order data" do
      order = %Order{id: "invalid-order", status: nil, dishes: [], payment_request_id: nil}

      assert {:error, {:validation_failed, changeset}} = Store.save_order(order)
      assert Keyword.has_key?(changeset.errors, :status)
    end

    test "save_order/1 rejects non-struct arguments" do
      assert {:error, {:invalid_argument, :order}} = Store.save_order(%{})
    end

    test "save_order/1 rejects duplicate dish ids" do
      order = %Order{id: "dup-order", status: :draft, dishes: ["dish", "dish"], payment_request_id: nil}

      assert {:error, {:duplicate_dishes, ["dish"]}} = Store.save_order(order)
      assert Repo.get(OrderRecord, order.id) == nil
    end

    test "save_order/1 rejects non-binary dish ids" do
      order = %Order{id: "bad-dish-order", status: :draft, dishes: ["ok", 123], payment_request_id: nil}

      assert {:error, {:invalid_dish_id, 123}} = Store.save_order(order)
    end

    test "save_payment/1 returns validation error for invalid payload" do
      order = %Order{id: "for-payment", status: :draft, dishes: [], payment_request_id: nil}
      assert :ok = Store.save_order(order)

      payment = %PaymentRequest{id: "payment-invalid", order_id: order.id, status: nil, details: nil}

      assert {:error, {:validation_failed, changeset}} = Store.save_payment(payment)
      assert Keyword.has_key?(changeset.errors, :status)
    end

    test "save_payment/1 rejects non-struct arguments" do
      assert {:error, {:invalid_argument, :payment_request}} = Store.save_payment(%{})
    end
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
