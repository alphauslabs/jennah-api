# Release pipeline

One proto revision, one release, every language. `.github/workflows/main.yml`
drives it; this directory holds the per-language steps.

| Event | What happens |
|---|---|
| Push to `main`, or a pull request | Generate every language, then assemble, build and test every SDK against its current `main`, including the shared conformance suite, then run the cross-language session tests over the SDKs just tested. Nothing is published. |
| Push a `v*` tag (e.g. `v0.61.0`) | The same, then publish every SDK at that version, but only if every language passed. |

To release: tag `jennah-api`, not the SDK repos.

```bash
git tag v0.61.0 && git push origin v0.61.0
```

## Why a failure in one language publishes nothing

`publish` depends on the whole `verify` matrix and on `crosslang`, so it does
not start unless every language built, passed its tests, passed
`conformance/`, and kept the other languages authenticated across a shared
session file (`crosslang/`). That covers every failure that is about the code.

The one gap left: publishing to three registries cannot be made a single
transaction, and two of them (PyPI, npm) cannot take an upload back. The order
is PyPI, then npm, then the Go push, and every step is a no-op when its registry
already holds this release: the PyPI step runs with `skip-existing`,
`typescript/publish.sh` skips a version npm already has with the same tarball
integrity (and refuses one with different content), and `go/publish.sh` skips a
tag already on the verified tree. So if any step fails, re-run the `publish`
job and it completes. A version names one artifact forever: re-running never
moves an existing SDK tag or replaces a published package.

`go/publish.sh` also refuses if `jennah-sdk-go` `main` moved between verify
and publish, rather than pushing the verified tree over a newer commit. Delete
and re-push the `jennah-api` tag to release again from the new `main`.

## A new RPC needs a retry class in every SDK first

Each SDK has a guard that fails when an RPC the generated code publishes is in
none of its retry classes (Go `TestEveryMethodIsClassified`, Python
`test_every_method_is_classified_exactly_once`, TypeScript
`every method is classified exactly once`), and one that fails on a class naming
an RPC that no longer exists. So before tagging a release that adds or renames
an RPC, commit and push its classification to `main` of all three:
`jennah-sdk-go`, `jennah-sdk-py` (`src/jennah/_retry.py`) and `jennah-sdk-ts`
(`src/retry.ts`). Otherwise verify fails and nothing publishes.

## Adding a language

1. Add its plugins to `buf.gen.yaml`, writing to `generated/<lang>`.
2. Add `<lang>` to the `verify` matrix in `main.yml`.
3. Add `release/<lang>/verify.sh`: clone the SDK, overlay `generated/<lang>` and
   `conformance/`, test (the conformance harness included), and leave what
   publish needs in `out/`.
4. Add its publish step to the `publish` job: `release/<lang>/publish.sh`, or a
   registry's own action.

## Cross-language session tests

`crosslang/run.sh` builds a small Go program against the verified
`jennah-sdk-go` tree, installs a small Node program (`tshelper/`) against the
verified `jennah-sdk-ts` tarball, and drives both and the verified
`jennah-sdk-py` against one fake platform and one session file: a renewal in any
language leaves the others authenticated, renewals chain across all three, and
concurrent reads and writes from all three never see a torn file. Locally:

```bash
# assembled checkouts; the TypeScript one built (npm run build), or verify's out/
release/crosslang/run.sh ../jennah-sdk-go ../jennah-sdk-py ../jennah-sdk-ts
```

`jnh` is not in this job: it renews over the HTTP gateway and lives in another
repository. Its side was checked live against production when this was built.

## One-time setup

- `GH_TOKEN` secret: can push to `jennah-sdk-go` and read `jennah-sdk-py` and
  `jennah-sdk-ts`.
- A `release` environment on this repository. Add required reviewers to it to
  get a manual approval before anything publishes.
- npm trusted publisher for the `jennah-sdk-ts` package: repository
  `alphauslabs/jennah-api`, workflow `main.yml`, environment `release`.
  Publishes carry provenance.
- PyPI trusted publisher for the `jennah-sdk-py` project: owner `alphauslabs`,
  repository `jennah-api`, workflow `main.yml`, environment `release`. No upload
  token is stored anywhere.

## Running locally

Each script takes `SDK_REPO` to clone from a local checkout instead of GitHub:

```bash
buf generate
SDK_REPO=../jennah-sdk-go release/go/verify.sh
SDK_REPO=../jennah-sdk-ts release/typescript/verify.sh
```

`typescript/publish.sh` can be dry-run against a local registry such as
verdaccio: set `npm_config_registry` to it and `NPM_PROVENANCE=false`
(provenance needs the Actions OIDC token).

`buf generate` now needs network access: the Python plugins are remote BSR
plugins.
