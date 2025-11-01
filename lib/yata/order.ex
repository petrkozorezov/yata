defmodule Yata.Order do
  @moduledoc """
  Domain aggregate for a customer's order.
  """

  @enforce_keys [:id, :status, :dishes]
  defstruct [:id, :status, :dishes, :payment_request_id]

  alias __MODULE__
  alias Yata.Order.Event

  @type id :: String.t()
  @type dish_id :: String.t()
  @type status :: :draft | :placed | :payment_pending | :completed | :cancelled
  @type t :: %Order{
          id: id(),
          status: status(),
          dishes: [dish_id()],
          payment_request_id: Yata.PaymentRequest.id() | nil
        }
  @type error ::
          {:error, :empty_order}
          | {:error, {:dish_not_found, dish_id()}}
          | {:error, {:unexpected_status, status(), atom()}}
          | {:error, {:invalid_argument, atom()}}
  @type command_result :: {:ok, t(), [Event.t()]} | error()

  defmodule Event do
    @moduledoc false

    @enforce_keys [:name, :data]
    defstruct [:name, :data]

    @type t :: %__MODULE__{
            name: atom(),
            data: map()
          }
  end

  @spec create(keyword()) :: command_result()
  def create(opts \\ []) do
    id = Keyword.get_lazy(opts, :id, &generate_id/0)

    order = %Order{
      id: id,
      status: :draft,
      dishes: [],
      payment_request_id: nil
    }

    {:ok, order, [event(:order_created, %{order_id: id})]}
  end

  @spec add_dish(t(), dish_id()) :: command_result()
  def add_dish(%Order{status: :draft} = order, dish_id) when is_binary(dish_id) do
    cond do
      String.trim(dish_id) == "" ->
        {:error, {:invalid_argument, :dish_id}}

      dish_id in order.dishes ->
        {:ok, order, []}

      true ->
        updated = %{order | dishes: order.dishes ++ [dish_id]}
        {:ok, updated, [event(:dish_added_to_order, %{order_id: order.id, dish_id: dish_id})]}
    end
  end

  def add_dish(%Order{} = order, _dish_id),
    do: unexpected_status(order, :add_dish)

  def add_dish(_, _),
    do: {:error, {:invalid_argument, :order}}

  @spec remove_dish(t(), dish_id()) :: command_result()
  def remove_dish(%Order{status: :draft} = order, dish_id) when is_binary(dish_id) do
    if dish_id in order.dishes do
      updated = %{order | dishes: List.delete(order.dishes, dish_id)}
      {:ok, updated, [event(:dish_removed_from_order, %{order_id: order.id, dish_id: dish_id})]}
    else
      {:error, {:dish_not_found, dish_id}}
    end
  end

  def remove_dish(%Order{} = order, _dish_id),
    do: unexpected_status(order, :remove_dish)

  def remove_dish(_, _),
    do: {:error, {:invalid_argument, :order}}

  @spec place(t()) :: command_result()
  def place(%Order{status: :draft, dishes: []}), do: {:error, :empty_order}

  def place(%Order{status: :draft} = order) do
    updated = %{order | status: :placed}
    {:ok, updated, [event(:order_placed, %{order_id: order.id})]}
  end

  def place(%Order{} = order), do: unexpected_status(order, :place_order)
  def place(_), do: {:error, {:invalid_argument, :order}}

  @spec mark_payment_pending(t(), Yata.PaymentRequest.id()) :: command_result()
  def mark_payment_pending(%Order{status: :placed} = order, payment_request_id)
      when is_binary(payment_request_id) do
    updated = %{order | status: :payment_pending, payment_request_id: payment_request_id}

    {:ok, updated,
     [
       event(:order_marked_payment_pending, %{
         order_id: order.id,
         payment_request_id: payment_request_id
       })
     ]}
  end

  def mark_payment_pending(%Order{} = order, _),
    do: unexpected_status(order, :mark_payment_pending)

  def mark_payment_pending(_, _),
    do: {:error, {:invalid_argument, :order}}

  @spec complete(t()) :: command_result()
  def complete(%Order{status: :payment_pending} = order) do
    updated = %{order | status: :completed}
    {:ok, updated, [event(:order_completed, %{order_id: order.id})]}
  end

  def complete(%Order{} = order), do: unexpected_status(order, :complete_order)
  def complete(_), do: {:error, {:invalid_argument, :order}}

  @spec cancel(t(), keyword()) :: command_result()
  def cancel(order, opts \\ [])

  def cancel(%Order{status: status} = order, opts)
      when status in [:payment_pending, :placed] do
    reason = Keyword.get(opts, :reason)
    updated = %{order | status: :cancelled}

    {:ok, updated,
     [
       event(:order_cancelled, %{
         order_id: order.id,
         reason: reason
       })
     ]}
  end

  def cancel(%Order{} = order, _opts), do: unexpected_status(order, :cancel_order)
  def cancel(_, _opts), do: {:error, {:invalid_argument, :order}}

  defp unexpected_status(%Order{status: status}, action) do
    {:error, {:unexpected_status, status, action}}
  end

  defp generate_id, do: :erl_snowflake.generate(:b62)

  defp event(name, data), do: %Event{name: name, data: data}
end
