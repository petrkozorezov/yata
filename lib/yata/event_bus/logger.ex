defmodule Yata.EventBus.Logger do
  @moduledoc """
  Simple implementation that logs domain events.
  """

  @behaviour Yata.EventBus

  require Logger

  @impl true
  def publish(events) when is_list(events) do
    Enum.each(events, fn event ->
      Logger.info(fn ->
        "[event] #{inspect(event.__struct__)} #{inspect(Map.from_struct(event))}"
      end)
    end)

    :ok
  end

  @impl true
  def subscribe(_pid), do: :ok
end
