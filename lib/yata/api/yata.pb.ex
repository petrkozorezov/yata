defmodule Yata.Api.Status do
  @moduledoc false

  use Protobuf, enum: true, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:Ok, 0)
  field(:BadOrderID, 1)
  field(:BadOrderStatus, 2)
end

defmodule Yata.Api.PaymentStatus do
  @moduledoc false

  use Protobuf, enum: true, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:Succeed, 0)
  field(:Failed, 1)
end

defmodule Yata.Api.OrderStatus do
  @moduledoc false

  use Protobuf, enum: true, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:Draft, 0)
  field(:Placed, 1)
  field(:PaymentPending, 2)
  field(:Completed, 3)
  field(:Cancelled, 4)
end

defmodule Yata.Api.PaymentReadStatus do
  @moduledoc false

  use Protobuf, enum: true, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:Pending, 0)
  field(:Succeeded, 1)
  field(:Failed, 2)
end

defmodule Yata.Api.GeneralResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:status, 1, type: Yata.Api.Status, enum: true)
end

defmodule Yata.Api.CreateOrderRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3
end

defmodule Yata.Api.CreateOrderResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:order_id, 1, type: :string, json_name: "orderId")
end

defmodule Yata.Api.AddDishRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:order_id, 1, type: :string, json_name: "orderId")
  field(:dish_id, 2, type: :string, json_name: "dishId")
end

defmodule Yata.Api.RemoveDishRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:order_id, 1, type: :string, json_name: "orderId")
  field(:dish_id, 2, type: :string, json_name: "dishId")
end

defmodule Yata.Api.PlaceOrderRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:order_id, 1, type: :string, json_name: "orderId")
end

defmodule Yata.Api.GetOrderStatusRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:order_id, 1, type: :string, json_name: "orderId")
end

defmodule Yata.Api.PaymentInfo do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:payment_id, 1, type: :string, json_name: "paymentId")
  field(:status, 2, type: Yata.Api.PaymentReadStatus, enum: true)
  field(:details, 3, type: :string)
end

defmodule Yata.Api.GetOrderStatusResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:order_id, 1, type: :string, json_name: "orderId")
  field(:status, 2, type: Yata.Api.OrderStatus, enum: true)
  field(:dishes, 3, repeated: true, type: :string)
  field(:payment, 4, type: Yata.Api.PaymentInfo)
end

defmodule Yata.Api.PaymentResultRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:payment_id, 1, type: :string, json_name: "paymentId")
  field(:status, 2, type: Yata.Api.PaymentStatus, enum: true)
  field(:details, 3, type: :string)
end

defmodule Yata.Api.PaymentResultResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3
end

defmodule Yata.Api.UserService.Service do
  @moduledoc false

  use GRPC.Service, name: "yata.api.UserService", protoc_gen_elixir_version: "0.14.1"

  rpc(:create_order, Yata.Api.CreateOrderRequest, Yata.Api.CreateOrderResponse)

  rpc(:add_dish, Yata.Api.AddDishRequest, Yata.Api.GeneralResponse)

  rpc(:remove_dish, Yata.Api.RemoveDishRequest, Yata.Api.GeneralResponse)

  rpc(:place_order, Yata.Api.PlaceOrderRequest, Yata.Api.GeneralResponse)

  rpc(:get_order_status, Yata.Api.GetOrderStatusRequest, Yata.Api.GetOrderStatusResponse)
end

defmodule Yata.Api.UserService.Stub do
  @moduledoc false

  use GRPC.Stub, service: Yata.Api.UserService.Service
end

defmodule Yata.Api.PaymentCallbacks.Service do
  @moduledoc false

  use GRPC.Service, name: "yata.api.PaymentCallbacks", protoc_gen_elixir_version: "0.14.1"

  rpc(:payment_result, Yata.Api.PaymentResultRequest, Yata.Api.PaymentResultResponse)
end

defmodule Yata.Api.PaymentCallbacks.Stub do
  @moduledoc false

  use GRPC.Stub, service: Yata.Api.PaymentCallbacks.Service
end
