defmodule Yata.Api.Server do
  @moduledoc """
  gRPC server for user-facing order commands.
  """

  use GRPC.Server, service: Yata.Api.UserService.Service

  alias Yata.Api.{
    AddDishRequest,
    CreateOrderRequest,
    CreateOrderResponse,
    GeneralResponse,
    PlaceOrderRequest,
    RemoveDishRequest
  }

  alias Yata.Orders.CommandHandler, as: OrderHandler

  def create_order(%CreateOrderRequest{}, _stream) do
    case OrderHandler.create_order() do
      {:ok, order, _events} ->
        %CreateOrderResponse{order_id: order.id}

      {:error, reason} ->
        raise rpc_error(:internal, "create_order_failed: #{inspect(reason)}")
    end
  end

  def add_dish(%AddDishRequest{order_id: order_id, dish_id: dish_id}, _stream) do
    order_id
    |> OrderHandler.add_dish(dish_id)
    |> to_general_response()
  end

  def remove_dish(%RemoveDishRequest{order_id: order_id, dish_id: dish_id}, _stream) do
    order_id
    |> OrderHandler.remove_dish(dish_id)
    |> to_general_response()
  end

  def place_order(%PlaceOrderRequest{order_id: order_id}, _stream) do
    case OrderHandler.place(order_id) do
      {:ok, _order, _} ->
        ok_response()

      {:error, :not_found} ->
        response(:BadOrderID)

      {:error, {:unexpected_status, _status, _action}} ->
        response(:BadOrderStatus)

      {:error, reason} ->
        raise rpc_error(:internal, "place_order_failed: #{inspect(reason)}")
    end
  end

  defp to_general_response({:ok, _order, _events}), do: ok_response()
  defp to_general_response({:error, :not_found}), do: response(:BadOrderID)

  defp to_general_response({:error, {:unexpected_status, _status, _action}}),
    do: response(:BadOrderStatus)

  defp to_general_response({:error, {:dish_not_found, _dish_id}}),
    do: response(:BadOrderStatus)

  defp to_general_response({:error, {:invalid_argument, _}}),
    do: response(:BadOrderStatus)

  defp to_general_response({:error, reason}),
    do: raise(rpc_error(:internal, "order_command_failed: #{inspect(reason)}"))

  defp ok_response, do: response(:Ok)

  defp response(status) do
    %GeneralResponse{status: status}
  end

  defp rpc_error(status, message) do
    GRPC.RPCError.exception(status: status, message: message)
  end
end

defmodule Yata.Api.PaymentCallbacksServer do
  @moduledoc """
  gRPC server for payment service callbacks.
  """

  use GRPC.Server, service: Yata.Api.PaymentCallbacks.Service

  alias Yata.Api.{PaymentResultRequest, PaymentResultResponse}
  alias Yata.Payments.CommandHandler, as: PaymentHandler

  def payment_result(
        %PaymentResultRequest{payment_id: payment_id, status: status, details: details},
        _stream
      ) do
    case status do
      :Succeed ->
        handle_payment_succeeded(payment_id, details)

      :Failed ->
        handle_payment_failed(payment_id, details)
    end
  end

  defp handle_payment_succeeded(payment_id, details) do
    case PaymentHandler.mark_succeeded(payment_id, details: details) do
      {:ok, _payment, _} ->
        %PaymentResultResponse{}

      {:error, :not_found} ->
        raise rpc_error(:not_found, "payment_not_found")

      {:error, {:unexpected_status, status, _action}} ->
        raise rpc_error(:failed_precondition, "unexpected_payment_status: #{status}")

      {:error, reason} ->
        raise rpc_error(:internal, "payment_success_handling_failed: #{inspect(reason)}")
    end
  end

  defp handle_payment_failed(payment_id, details) do
    case PaymentHandler.mark_failed(payment_id, details: details, reason: details) do
      {:ok, _payment, _} ->
        %PaymentResultResponse{}

      {:error, :not_found} ->
        raise rpc_error(:not_found, "payment_not_found")

      {:error, {:unexpected_status, status, _action}} ->
        raise rpc_error(:failed_precondition, "unexpected_payment_status: #{status}")

      {:error, reason} ->
        raise rpc_error(:internal, "payment_failure_handling_failed: #{inspect(reason)}")
    end
  end

  defp rpc_error(status, message) do
    GRPC.RPCError.exception(status: status, message: message)
  end
end
