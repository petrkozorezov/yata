defmodule YataEctoStoreTest do
  use ExUnit.Case

  import Ecto.Query

  alias Yata.{Repo, Order, Store}
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
