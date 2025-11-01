defmodule Yata.EventBus.InMemory do
  @moduledoc """
  Simple in-memory event bus that broadcasts to subscribed processes.
  """

  use GenServer

  @behaviour Yata.EventBus

  require Logger

  @type state :: %{subscribers: MapSet.t(pid())}

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

  ## Yata.EventBus callbacks

  @impl true
  def publish(events) when is_list(events) do
    GenServer.cast(__MODULE__, {:publish, events})
  end

  @impl true
  def subscribe(pid) when is_pid(pid) do
    GenServer.call(__MODULE__, {:subscribe, pid})
  end

  ## GenServer callbacks

  @impl true
  def init(_opts) do
    {:ok, %{subscribers: MapSet.new()}}
  end

  @impl true
  def handle_call({:subscribe, pid}, _from, %{subscribers: subs} = state) do
    Process.monitor(pid)
    {:reply, :ok, %{state | subscribers: MapSet.put(subs, pid)}}
  end

  @impl true
  def handle_cast({:publish, events}, %{subscribers: subscribers} = state) do
    for event <- events,
        pid <- MapSet.to_list(subscribers) do
      send(pid, {:yata_event, event})
    end

    :ok =
      Enum.reduce(events, :ok, fn event, _ ->
        Logger.info(fn ->
          "[event] #{inspect(event.__struct__)} #{inspect(Map.from_struct(event))}"
        end)

        :ok
      end)

    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, %{subscribers: subs} = state) do
    {:noreply, %{state | subscribers: MapSet.delete(subs, pid)}}
  end

  @impl true
  def handle_info(_, state), do: {:noreply, state}
end
