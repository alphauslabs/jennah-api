#!/usr/bin/env bash
# Assembles jennah-sdk-go from its current main plus this revision's generated
# code and conformance suite, then builds and tests it. On success, out/ holds
# exactly the tree that publish.sh will push, and the commit it was built on.
#
# Env:
#   DEPLOYER_TOKEN  GitHub token able to read the SDK repo (optional if public)
#   VERSION         the release tag, or empty for a non-release build (unused
#                   here: a Go module's version is its git tag, set at publish)
#   SDK_REPO        override the clone source, for running this locally
set -euo pipefail

ROOT=$PWD
OUT=$ROOT/out
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
REPO=${SDK_REPO:-https://${DEPLOYER_TOKEN:+$DEPLOYER_TOKEN@}github.com/alphauslabs/jennah-sdk-go}

rm -rf "$OUT" && mkdir -p "$OUT"
git clone --quiet "$REPO" "$WORK/sdk"
cd "$WORK/sdk"
git rev-parse HEAD >"$OUT/base"

# Generated code only ever lands under jennah/, so the hand-written root package
# survives. Same overlay as before this workflow existed.
cp -r "$ROOT"/generated/go/* .
# Replaced wholesale so a case removed from the suite is removed here too.
rm -rf conformance && cp -r "$ROOT/conformance" .

go build ./...
go vet ./...
# Includes TestCredentialConformance: the shared suite gates the release.
go test -count=1 ./...

# The verified tree, minus git metadata. publish.sh restores it byte for byte.
tar --exclude=.git -czf "$OUT/tree.tgz" .
echo "jennah-sdk-go verified on $(cat "$OUT/base")"
