[![main](https://github.com/alphauslabs/jennah-api/actions/workflows/main.yml/badge.svg)](https://github.com/alphauslabs/jennah-api/actions/workflows/main.yml)

## jennah-api

You need to install the following tools to build locally:

* The [protoc](https://grpc.io/docs/protoc-installation/) compiler.
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

  OpenAPI generation uses [gnostic's](https://github.com/google/gnostic) `protoc-gen-openapi` (OpenAPI v3), not grpc-gateway's `protoc-gen-openapiv2` (Swagger 2.0).

* The [buf](https://docs.buf.build/installation) tool.

Then run:

```bash
$ buf format -w && buf dep update && buf generate
```

CI generates and tests every SDK on each push. Pushing a `v*` tag here releases
[jennah-sdk-go](https://github.com/alphauslabs/jennah-sdk-go) and
[jennah-sdk-py](https://github.com/alphauslabs/jennah-sdk-py) together at that
version; see [`ci/README.md`](ci/README.md).

## Conformance suites

[`conformance/`](conformance/README.md) holds language-independent cases every
SDK must pass before it is released, starting with the shared credential
contract. CI copies the directory into each SDK with the generated code, so an
SDK always runs the cases from the revision its stubs came from.

Two rules, both part of the release process rather than conventions:

* **A new credential behavior enters the suite before it enters any SDK.** Land
  the case here first, see it fail in every SDK that lacks the behavior, then
  implement it. A change that adds credential behavior to an SDK with no case
  already in this directory is not ready for review.
* **A failing case is a defect in the SDK.** Fix the client. A case changes only
  when the spec it cites changes.
