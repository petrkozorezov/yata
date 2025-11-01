defmodule Yata.Store do
  @moduledoc """
  Persistence layer for orders and payment requests backed by Ecto.
  """

  import Ecto.Query

  alias Ecto.Changeset
  alias Yata.{Order, PaymentRequest, Repo}
  alias Yata.Store.{OrderDishRecord, OrderRecord, PaymentRecord}

  # Orders ------------------------------------------------------------------

  @spec fetch_order(Order.id()) :: {:ok, Order.t()} | {:error, term()}
  def fetch_order(id) when is_binary(id) do
    case Repo.one(order_query(id)) do
      nil -> {:error, :not_found}
      record -> {:ok, to_order(record)}
    end
  end

  def fetch_order(_), do: {:error, {:invalid_argument, :order_id}}

  @spec save_order(Order.t()) :: :ok | {:error, term()}
  def save_order(%Order{} = order) do
    case Repo.transaction(fn ->
           with {:ok, _} <- upsert_order(order),
                :ok <- replace_dishes(order.id, order.dishes) do
             :ok
           else
             {:error, reason} -> Repo.rollback(reason)
             other -> Repo.rollback(other)
           end
         end) do
      {:ok, :ok} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  def save_order(_), do: {:error, {:invalid_argument, :order}}

  # Payments ----------------------------------------------------------------

  @spec fetch_payment(PaymentRequest.id()) :: {:ok, PaymentRequest.t()} | {:error, term()}
  def fetch_payment(id) when is_binary(id) do
    case Repo.get(PaymentRecord, id) do
      nil -> {:error, :not_found}
      record -> {:ok, to_payment(record)}
    end
  end

  def fetch_payment(_), do: {:error, {:invalid_argument, :payment_id}}

  @spec save_payment(PaymentRequest.t()) :: :ok | {:error, term()}
  def save_payment(%PaymentRequest{} = payment) do
    changeset =
      case Repo.get(PaymentRecord, payment.id) do
        nil -> PaymentRecord.changeset(%PaymentRecord{id: payment.id}, payment_attrs(payment))
        record -> PaymentRecord.changeset(record, payment_attrs(payment))
      end

    case Repo.insert_or_update(changeset) do
      {:ok, _} -> :ok
      {:error, %Changeset{} = changeset} -> {:error, {:validation_failed, changeset}}
    end
  end

  def save_payment(_), do: {:error, {:invalid_argument, :payment_request}}

  # Internal helpers --------------------------------------------------------

  defp order_query(id) do
    from(o in OrderRecord,
      where: o.id == ^id,
      preload: [dishes: ^from(d in OrderDishRecord, order_by: d.position)]
    )
  end

  defp upsert_order(%Order{} = order) do
    changeset =
      case Repo.get(OrderRecord, order.id) do
        nil -> OrderRecord.changeset(%OrderRecord{id: order.id}, order_attrs(order))
        record -> OrderRecord.changeset(record, order_attrs(order))
      end

    case Repo.insert_or_update(changeset) do
      {:ok, record} -> {:ok, record}
      {:error, %Changeset{} = changeset} -> {:error, {:validation_failed, changeset}}
    end
  end

  defp replace_dishes(order_id, dishes) do
    with :ok <- validate_dishes(dishes) do
      Repo.delete_all(from(d in OrderDishRecord, where: d.order_id == ^order_id))

      entries =
        dishes
        |> Enum.with_index()
        |> Enum.map(fn {dish_id, index} ->
          %{
            order_id: order_id,
            dish_id: dish_id,
            position: index,
            inserted_at: utc_now()
          }
        end)

      case entries do
        [] ->
          :ok

        entries ->
          try do
            {count, _} = Repo.insert_all(OrderDishRecord, entries)
            if count == length(entries), do: :ok, else: {:error, :dish_persist_failed}
          rescue
            error ->
              {:error, {:persist_failed, error}}
          end
      end
    end
  end

  defp to_order(%OrderRecord{} = record) do
    dishes =
      record.dishes
      |> Enum.sort_by(& &1.position)
      |> Enum.map(& &1.dish_id)

    %Order{
      id: record.id,
      status: record.status,
      dishes: dishes,
      payment_request_id: record.payment_request_id
    }
  end

  defp to_payment(%PaymentRecord{} = record) do
    %PaymentRequest{
      id: record.id,
      order_id: record.order_id,
      status: record.status,
      details: record.details
    }
  end

  defp order_attrs(%Order{} = order) do
    %{
      id: order.id,
      status: order.status,
      payment_request_id: order.payment_request_id
    }
  end

  defp payment_attrs(%PaymentRequest{} = payment) do
    %{
      id: payment.id,
      order_id: payment.order_id,
      status: payment.status,
      details: payment.details
    }
  end

  defp validate_dishes(dishes) do
    case Enum.find(dishes, &(not is_binary(&1))) do
      nil ->
        case find_duplicate_dishes(dishes) do
          [] -> :ok
          duplicates -> {:error, {:duplicate_dishes, duplicates}}
        end

      invalid ->
        {:error, {:invalid_dish_id, invalid}}
    end
  end

  defp find_duplicate_dishes(dishes) do
    dishes
    |> Enum.group_by(& &1)
    |> Enum.filter(fn {_dish_id, occurrences} -> length(occurrences) > 1 end)
    |> Enum.map(fn {dish_id, _} -> dish_id end)
    |> Enum.sort()
  end

  defp utc_now do
    NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
  end
end
