defmodule Yata do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        event_bus_child(),
        Yata.Repo,
        Yata.ProcessManagers.OrderPayment
      ]
      |> Enum.reject(&is_nil/1)

    opts = [strategy: :one_for_one, name: Yata.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp event_bus_child do
    case Application.get_env(:yata, :event_bus, Yata.EventBus.Logger) do
      Yata.EventBus.InMemory -> Yata.EventBus.InMemory
      _other -> nil
    end
  end
end
