module github.com/alphauslabs/jennah-api

go 1.26.4

require (
	github.com/golang/protobuf v1.5.4
	github.com/google/go-cmp v0.7.0
	github.com/grpc-ecosystem/grpc-gateway/v2 v2.29.0
	golang.org/x/text v0.38.0
	google.golang.org/genproto/googleapis/api v0.0.0-20260622175928-b703f567277d
	google.golang.org/genproto/googleapis/rpc v0.0.0-20260622175928-b703f567277d
	google.golang.org/grpc v1.81.1
	google.golang.org/protobuf v1.36.11
	gopkg.in/yaml.v3 v3.0.1
)

require (
	github.com/google/gnostic v0.7.1 // indirect
	github.com/google/gnostic-models v0.7.0 // indirect
	github.com/kr/text v0.2.0 // indirect
	github.com/rogpeppe/go-internal v1.15.0 // indirect
	go.yaml.in/yaml/v3 v3.0.4 // indirect
	golang.org/x/net v0.51.0 // indirect
	golang.org/x/sys v0.42.0 // indirect
	google.golang.org/grpc/cmd/protoc-gen-go-grpc v1.6.2 // indirect
)

tool (
	github.com/google/gnostic/cmd/protoc-gen-openapi
	github.com/grpc-ecosystem/grpc-gateway/v2/protoc-gen-grpc-gateway
	github.com/grpc-ecosystem/grpc-gateway/v2/protoc-gen-openapiv2
	google.golang.org/grpc/cmd/protoc-gen-go-grpc
	google.golang.org/protobuf/cmd/protoc-gen-go
)
