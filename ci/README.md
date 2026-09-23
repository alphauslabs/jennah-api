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
`conformance/`, and kept the other language authenticated across a shared
session file (`crosslang/`). That covers every failure that is about the code.

The one gap left: publishing to two registries cannot be made a single
transaction. PyPI goes first because an upload there cannot be withdrawn; the
Go push after it is idempotent (`go/publish.sh`), so if it fails, re-run the
`publish` job and it completes. A version tag names one tree forever: re-running
never moves an existing SDK tag.

`go/publish.sh` also refuses if `jennah-sdk-go` `main` moved between verify
and publish, rather than pushing the verified tree over a newer commit. Delete
and re-push the `jennah-api` tag to release again from the new `main`.

## Adding a language

1. Add its plugins to `buf.gen.yaml`, writing to `generated/<lang>`.
2. Add `<lang>` to the `verify` matrix in `main.yml`.
3. Add `ci/<lang>/verify.sh`: clone the SDK, overlay `generated/<lang>` and
   `conformance/`, test (the conformance harness included), and leave what
   publish needs in `out/`.
4. Add its publish step to the `publish` job: `ci/<lang>/publish.sh`, or a
   registry's own action.

## Cross-language session tests

`crosslang/run.sh` builds a small Go program against the verified
`jennah-sdk-go` tree and drives it and the verified `jennah-sdk-py` against one
fake platform and one session file: a renewal in either language leaves the
other authenticated, renewals chain across languages, and concurrent reads and
writes from both never see a torn file. Locally:

```bash
ci/crosslang/run.sh ../jennah-sdk-go ../jennah-sdk-py   # an assembled checkout
```

`jnh` is not in this job: it renews over the HTTP gateway and lives in another
repository. Its side was checked live against production when this was built.

## One-time setup

- `GH_TOKEN` secret: can push to `jennah-sdk-go` and read `jennah-sdk-py`.
- A `release` environment on this repository. Add required reviewers to it to
  get a manual approval before anything publishes.
- PyPI trusted publisher for the `jennah-sdk-py` project: owner `alphauslabs`,
  repository `jennah-api`, workflow `main.yml`, environment `release`. No upload
  token is stored anywhere.

## Running locally

Each script takes `SDK_REPO` to clone from a local checkout instead of GitHub:

```bash
buf generate
SDK_REPO=../jennah-sdk-go ci/go/verify.sh
```

`buf generate` now needs network access: the Python plugins are remote BSR
plugins.
