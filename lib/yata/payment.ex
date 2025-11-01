defmodule Yata.PaymentRequest do
  @moduledoc """
  Domain aggregate for payment requests associated with orders.
  """

  @enforce_keys [:id, :order_id, :status]
  defstruct [:id, :order_id, :status, :details]

  alias __MODULE__
  alias Yata.PaymentRequest.Event

  @type id :: String.t()
  @type status :: :pending | :succeeded | :failed
  @type t :: %PaymentRequest{
          id: id(),
          order_id: Yata.Order.id(),
          status: status(),
          details: map() | nil
        }
  @type error ::
          {:error, {:unexpected_status, status(), atom()}}
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

  @spec create(Yata.Order.id(), keyword()) :: command_result()
  def create(order_id, opts \\ [])

  def create(order_id, opts) when is_binary(order_id) do
    id = Keyword.get_lazy(opts, :id, &generate_id/0)
    details = Keyword.get(opts, :details)

    request = %PaymentRequest{
      id: id,
      order_id: order_id,
      status: :pending,
      details: details
    }

    {:ok, request,
     [
       event(:payment_requested, %{
         payment_id: id,
         order_id: order_id,
         details: details
       })
     ]}
  end

  def create(_, _), do: {:error, {:invalid_argument, :order_id}}

  @spec mark_succeeded(t(), keyword()) :: command_result()
  def mark_succeeded(request, opts \\ [])

  def mark_succeeded(%PaymentRequest{status: :pending} = request, opts) do
    details = merge_details(request.details, Keyword.get(opts, :details))
    updated = %{request | status: :succeeded, details: details}

    {:ok, updated,
     [
       event(:payment_succeeded, %{
         payment_id: request.id,
         order_id: request.order_id,
         details: details
       })
     ]}
  end

  def mark_succeeded(%PaymentRequest{} = request, _opts),
    do: unexpected_status(request, :mark_payment_succeeded)

  def mark_succeeded(_, _), do: {:error, {:invalid_argument, :payment_request}}

  @spec mark_failed(t(), keyword()) :: command_result()
  def mark_failed(request, opts \\ [])

  def mark_failed(%PaymentRequest{status: :pending} = request, opts) do
    reason = Keyword.get(opts, :reason)
    details = merge_details(request.details, Keyword.get(opts, :details))
    updated = %{request | status: :failed, details: details}

    {:ok, updated,
     [
       event(:payment_failed, %{
         payment_id: request.id,
         order_id: request.order_id,
         reason: reason,
         details: details
       })
     ]}
  end

  def mark_failed(%PaymentRequest{} = request, _opts),
    do: unexpected_status(request, :mark_payment_failed)

  def mark_failed(_, _), do: {:error, {:invalid_argument, :payment_request}}

  defp unexpected_status(%PaymentRequest{status: status}, action) do
    {:error, {:unexpected_status, status, action}}
  end

  defp generate_id, do: :erl_snowflake.generate(:b62)

  defp merge_details(nil, nil), do: nil
  defp merge_details(existing, nil), do: existing
  defp merge_details(nil, incoming), do: incoming

  defp merge_details(existing, incoming) when is_map(existing) and is_map(incoming),
    do: Map.merge(existing, incoming)

  defp merge_details(_, incoming), do: incoming

  defp event(name, data), do: %Event{name: name, data: data}
end
