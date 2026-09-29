#!/usr/bin/env bash
# Lays this revision's generated TypeScript, conformance suite and version over
# a jennah-sdk-ts checkout. Used by verify.sh in CI, and by jennah-sdk-ts's
# scripts/dev-generate.sh locally, so both assemble the SDK the same way. Run
# `buf generate` in jennah-api first.
#
# Layout this expects of jennah-sdk-ts:
#   src/*.ts            hand-written SDK, flat
#   src/gen/            generated (messages and service descriptors), replaced
#                       wholesale here
#   src/version.ts      written here
#   conformance/        copied here; the TypeScript harness reads it
#   package.json        its "version" is set here; @bufbuild/protobuf at the
#                       version buf.gen.yaml pins the es plugin to
#
# Generated code is not committed to jennah-sdk-ts. It exists in the published
# tarball only, so the repository cannot drift from the proto it claims.
#
# Usage: assemble.sh <jennah-sdk-ts dir>
# Env:   VERSION  the release tag (v1.2.3), or empty for a non-release build
set -euo pipefail

API=$(cd "$(dirname "$0")/../.." && pwd)
SDK=$(cd "${1:?usage: assemble.sh <jennah-sdk-ts dir>}" && pwd)
GEN=$API/generated/ts
[[ -d $GEN/jennah ]] || { echo "no generated TypeScript in $GEN: run buf generate in jennah-api" >&2; exit 1; }

# npm semver: v1.2.3 publishes as 1.2.3. A non-release build gets a prerelease
# version that the release would never be asked to publish.
if [[ -n ${VERSION:-} ]]; then
  [[ $VERSION =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "not a release tag: $VERSION" >&2; exit 1; }
  TSVER=${VERSION#v}
else
  TSVER=0.0.0-dev.0
fi

cd "$SDK"
rm -rf src/gen
mkdir -p src/gen
cp -r "$GEN"/* src/gen/

rm -rf conformance && cp -r "$API/conformance" .

cat >src/version.ts <<EOF
// Written by jennah-api release/typescript/assemble.sh; not committed.
export const version = "$TSVER";
export const sourceCommit = "$(git rev-parse --verify --quiet HEAD || echo unknown)";
EOF
npm pkg set version="$TSVER" >/dev/null
echo "$TSVER"
