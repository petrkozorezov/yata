defmodule YataOrderPropertyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Yata.Order
  alias Yata.TestSupport.OrderModel

  test "model-based order state transitions stay in sync with aggregate" do
    generator =
      bind(integer(2..4), fn order_count ->
        multi_command_sequence(order_count)
        |> map(fn commands -> {order_count, commands} end)
      end)

    check all {order_count, commands} <- generator do
      %{ids: order_ids, orders: orders_map, models: models_map} = build_orders(order_count)

      {final_orders, final_models} =
        Enum.reduce(commands, {orders_map, models_map}, fn {order_idx, command}, {orders, models} ->
          order_id = Enum.fetch!(order_ids, order_idx)
          order = Map.fetch!(orders, order_id)
          model = Map.fetch!(models, order_id)

          case step(command, order, model) do
            {:ok, updated_order, updated_model} ->
              updated_orders = Map.put(orders, order_id, updated_order)
              updated_models = Map.put(models, order_id, updated_model)
              ensure_consistency(order_ids, updated_orders, updated_models)
              {updated_orders, updated_models}

            {:error, _reason, _order, _model} ->
              ensure_consistency(order_ids, orders, models)
              {orders, models}
          end
        end)

      ensure_consistency(order_ids, final_orders, final_models)
    end
  end

  defp step(command, order, model) do
    agg_result = run_command(order, command)
    model_result = OrderModel.apply(model, command)

    case {agg_result, model_result} do
      {{:ok, updated_order, _events}, {:ok, updated_model}} ->
        OrderModel.assert_equivalent(updated_order, updated_model)
        {:ok, updated_order, updated_model}

      {{:error, reason}, {:error, reason}} ->
        {:error, reason, order, model}

      other ->
        flunk("mismatch between aggregate and model: #{inspect(other)}")
    end
  end

  defp run_command(order, {:add, dish_id}), do: Order.add_dish(order, dish_id)
  defp run_command(order, {:remove, dish_id}), do: Order.remove_dish(order, dish_id)
  defp run_command(order, :place), do: Order.place(order)
  defp run_command(order, {:mark_pending, payment_id}), do: Order.mark_payment_pending(order, payment_id)
  defp run_command(order, :complete), do: Order.complete(order)
  defp run_command(order, {:cancel, reason}), do: Order.cancel(order, reason: reason)
  defp run_command(order, :noop), do: {:ok, order, []}

  defp operation do
    dish_gen = string(:alphanumeric, min_length: 1)
    payment_gen = string(:alphanumeric, min_length: 1)
    reason_gen = string(:printable, min_length: 0, max_length: 8)

    one_of([
      map(dish_gen, &{:add, &1}),
      map(dish_gen, &{:remove, &1}),
      constant(:place),
      map(payment_gen, &{:mark_pending, &1}),
      constant(:complete),
      map(reason_gen, &{:cancel, &1}),
      constant(:noop)
    ])
  end

  defp multi_command_sequence(order_count) do
    tuple_gen =
      map({integer(0..(order_count - 1)), operation()}, fn {idx, command} ->
        {idx, command}
      end)

    tuple_gen
    |> list_of(max_length: 40)
    |> nonempty()
  end

  defp build_orders(order_count) do
    Enum.reduce(1..order_count, %{ids: [], orders: %{}, models: %{}}, fn _, acc ->
      {:ok, order, _} = Order.create()
      model = OrderModel.new(order)

      %{
        ids: [order.id | acc.ids],
        orders: Map.put(acc.orders, order.id, order),
        models: Map.put(acc.models, order.id, model)
      }
    end)
    |> then(fn %{ids: ids} = acc -> %{acc | ids: Enum.reverse(ids)} end)
  end

  defp ensure_consistency(order_ids, orders, models) do
    Enum.each(order_ids, fn id ->
      OrderModel.assert_equivalent(Map.fetch!(orders, id), Map.fetch!(models, id))
    end)
  end
end
