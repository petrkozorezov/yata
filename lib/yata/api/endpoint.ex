defmodule Yata.Api.Endpoint do
  use GRPC.Endpoint

  intercept(GRPC.Server.Interceptors.Logger)
  run(Yata.Api.Server)
  run(Yata.Api.PaymentCallbacksServer)
end
