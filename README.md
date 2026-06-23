[![main](https://github.com/alphauslabs/blueinternal/actions/workflows/main.yml/badge.svg)](https://github.com/alphauslabs/blueinternal/actions/workflows/main.yml)

You need to install the following tools to build locally:

* The [protoc](https://grpc.io/docs/protoc-installation/) compiler
* The compiler plugins. These are pinned in the `tool` directive of `go.mod`, so
  the simplest way to install all of them at their pinned versions is (Go 1.24+):

```bash
$ go install tool
```

  Or install them individually:

```bash
$ go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
$ go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest
$ go install github.com/grpc-ecosystem/grpc-gateway/v2/protoc-gen-grpc-gateway@latest
$ go install github.com/google/gnostic/cmd/protoc-gen-openapi@latest
```

  OpenAPI generation uses [gnostic's](https://github.com/google/gnostic)
  `protoc-gen-openapi` (OpenAPI v3, output to `generated/openapi/`), not
  grpc-gateway's `protoc-gen-openapiv2` (Swagger 2.0).

* The [buf](https://docs.buf.build/installation) tool

Then run:

```bash
$ buf dep update && buf generate
```

Generated SDKs from updates to this repository:

* [blue-internal-go](https://github.com/alphauslabs/blue-internal-go)
