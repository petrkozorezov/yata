{ pkgs, lib, config, inputs, ... }: {
  languages.elixir.enable = true;

  packages = with pkgs; [
    protobuf
    protoc-gen-elixir
  ];

  scripts.proto-compile.exec = "protoc -I priv/proto --elixir_out=plugins=grpc:lib/yata/api priv/proto/*.proto";
}
