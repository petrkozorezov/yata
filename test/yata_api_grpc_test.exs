defmodule YataApiGrpcTest do
  use ExUnit.Case

  alias Yata.Api.{
    AddDishRequest,
    CreateOrderRequest,
    CreateOrderResponse,
    GeneralResponse,
    GetOrderStatusRequest,
    GetOrderStatusResponse,
    PaymentInfo,
    PlaceOrderRequest
  }

  alias Yata.Api.UserService.Stub, as: UserStub
  alias Yata.Payments.CommandHandler, as: PaymentHandler
  alias Yata.Store.{OrderDishRecord, OrderRecord, PaymentRecord}
  alias Yata.Repo

  @tag :integration
  setup do
    cleanup_db()

    port = random_port()

    server =
      start_supervised!({
        GRPC.Server.Supervisor,
        endpoint: Yata.Api.Endpoint,
        port: port,
        start_server: true
      })

    _client =
      start_supervised!({GRPC.Client.Supervisor, []})

    {:ok, channel} = GRPC.Stub.connect("localhost:#{port}")

    on_exit(fn ->
      try do
        GRPC.Stub.disconnect(channel)
      catch
        :exit, _ -> :ok
      end

      try do
        Process.exit(server, :normal)
      catch
        :exit, _ -> :ok
      end

      cleanup_db()
    end)

    {:ok, channel: channel, server: server}
  end

  test "GetOrderStatus via gRPC returns pending payment snapshot", %{channel: channel} do
    {:ok, %CreateOrderResponse{order_id: order_id}} =
      UserStub.create_order(channel, %CreateOrderRequest{})

    assert {:ok, %GeneralResponse{status: :Ok}} =
             UserStub.add_dish(channel, %AddDishRequest{order_id: order_id, dish_id: "grpc-dish"})

    assert {:ok, %GeneralResponse{status: :Ok}} =
             UserStub.place_order(channel, %PlaceOrderRequest{order_id: order_id})

    response =
      wait_for(fn ->
        with {:ok, %GetOrderStatusResponse{} = resp} <-
               UserStub.get_order_status(channel, %GetOrderStatusRequest{order_id: order_id}) do
          case resp do
            %GetOrderStatusResponse{
              status: :PaymentPending,
              payment: %PaymentInfo{status: :Pending}
            } ->
              {:ok, resp}

            _ ->
              :retry
          end
        end
      end)

    assert response.order_id == order_id
    assert response.dishes == ["grpc-dish"]
    assert %PaymentInfo{payment_id: payment_id, status: :Pending} = response.payment
    assert payment_id != nil
  end

  test "GetOrderStatus via gRPC reflects payment success with JSON details", %{channel: channel} do
    {:ok, %CreateOrderResponse{order_id: order_id}} =
      UserStub.create_order(channel, %CreateOrderRequest{})

    assert {:ok, %GeneralResponse{status: :Ok}} =
             UserStub.add_dish(channel, %AddDishRequest{order_id: order_id, dish_id: "grpc-dish-2"})

    assert {:ok, %GeneralResponse{status: :Ok}} =
             UserStub.place_order(channel, %PlaceOrderRequest{order_id: order_id})

    payment_id =
      wait_for(fn ->
        with {:ok, %GetOrderStatusResponse{} = resp} <-
               UserStub.get_order_status(channel, %GetOrderStatusRequest{order_id: order_id}) do
          case resp.payment do
            %PaymentInfo{payment_id: payment_id} when is_binary(payment_id) -> {:ok, payment_id}
            _ -> :retry
          end
        end
      end)

    {:ok, _payment, _} = PaymentHandler.mark_succeeded(payment_id, details: %{"trace" => "ok"})

    response =
      wait_for(fn ->
        with {:ok, %GetOrderStatusResponse{} = resp} <-
               UserStub.get_order_status(channel, %GetOrderStatusRequest{order_id: order_id}) do
          case resp do
            %GetOrderStatusResponse{
              status: :Completed,
              payment: %PaymentInfo{status: :Succeeded}
            } ->
              {:ok, resp}

            _ ->
              :retry
          end
        end
      end)

    assert response.payment.details == ~s({"trace":"ok"})
  end

  test "GetOrderStatus via gRPC returns error for unknown order", %{channel: channel} do
    result =
      UserStub.get_order_status(channel, %GetOrderStatusRequest{order_id: "unknown"})

    assert {:error, %GRPC.RPCError{} = err} = result
    assert err.message == "order_not_found"
    assert err.status in [:not_found, 5]
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

  defp wait_for(fun, attempts \\ 50, delay \\ 30)
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

  defp random_port do
    Enum.random(50_000..59_999)
  end
end
