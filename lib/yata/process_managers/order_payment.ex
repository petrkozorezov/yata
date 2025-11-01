defmodule Yata.ProcessManagers.OrderPayment do
  @moduledoc """
  Coordinates order and payment lifecycle based on domain events.
  """

  use GenServer

  require Logger

  alias Yata.EventBus
  alias Yata.Orders.CommandHandler, as: OrderHandler
  alias Yata.Payments.CommandHandler, as: PaymentHandler
  alias Yata.Order.Event, as: OrderEvent
  alias Yata.PaymentRequest.Event, as: PaymentEvent

  ## Client API

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, Keyword.merge([name: __MODULE__], opts))
  end

  @spec child_spec(keyword()) :: Supervisor.child_spec()
  def child_spec(opts \\ []) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end

  ## GenServer callbacks

  @impl true
  def init(state) do
    :ok = EventBus.subscribe(self())
    {:ok, state}
  end

  @impl true
  def handle_info(
        {:yata_event, %OrderEvent{name: :order_placed, data: %{order_id: order_id}}},
        state
      ) do
    case PaymentHandler.create_request(order_id) do
      {:ok, payment, _} ->
        _ = OrderHandler.mark_payment_pending(order_id, payment.id)
        :ok

      {:error, reason} ->
        Logger.error("Failed to create payment request for order #{order_id}: #{inspect(reason)}")
    end

    {:noreply, state}
  end

  def handle_info(
        {:yata_event,
         %PaymentEvent{name: :payment_succeeded, data: %{order_id: order_id} = data}},
        state
      ) do
    case OrderHandler.complete(order_id) do
      {:ok, _order, _} ->
        Logger.debug(
          "Order #{order_id} completed after payment success: #{inspect(data.details)}"
        )

        :ok

      {:error, reason} ->
        Logger.error("Failed to complete order #{order_id}: #{inspect(reason)}")
    end

    {:noreply, state}
  end

  def handle_info(
        {:yata_event, %PaymentEvent{name: :payment_failed, data: %{order_id: order_id} = data}},
        state
      ) do
    reason = Map.get(data, :reason) || Map.get(data, :details)

    case OrderHandler.cancel(order_id, reason: reason) do
      {:ok, _order, _} ->
        Logger.debug("Order #{order_id} cancelled after payment failure: #{inspect(reason)}")
        :ok

      {:error, reason} ->
        Logger.error("Failed to cancel order #{order_id}: #{inspect(reason)}")
    end

    {:noreply, state}
  end

  def handle_info({:yata_event, _event}, state), do: {:noreply, state}
  def handle_info(_msg, state), do: {:noreply, state}
end
