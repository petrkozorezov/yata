defmodule Yata.EventBus do
  @moduledoc """
  Facade for publishing domain events.
  """

  @type event :: struct()
  @type events :: [event()]

  @callback publish(events()) :: :ok | {:error, term()}
  @callback subscribe(pid()) :: :ok | {:error, term()}

  @spec publish(events()) :: :ok | {:error, term()}
  def publish(events)

  def publish([]), do: :ok

  def publish(events) when is_list(events) do
    bus().publish(events)
  end

  def publish(_), do: {:error, {:invalid_argument, :events}}

  @spec subscribe(pid()) :: :ok | {:error, term()}
  def subscribe(pid \\ self())

  def subscribe(pid) when is_pid(pid) do
    bus().subscribe(pid)
  end

  def subscribe(_), do: {:error, {:invalid_argument, :pid}}

  defp bus do
    Application.get_env(:yata, :event_bus, Yata.EventBus.Logger)
  end
end
