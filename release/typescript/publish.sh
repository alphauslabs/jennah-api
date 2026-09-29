#!/usr/bin/env bash
# Publishes the tarball verify.sh packed to npm as jennah-sdk-ts $VERSION.
#
# Idempotent, because it runs after an irreversible PyPI upload and before the
# Go push, and must be safe to re-run until the release completes:
#   - the version is already on npm with this tarball's integrity: nothing to do
#   - the version is on npm with any other content: refuse (a version names one
#     tarball, forever, and npm would refuse the upload anyway)
#   - otherwise publish, with provenance, through npm trusted publishing (the
#     job's OIDC token; no upload token is stored anywhere)
#
# Usage: publish.sh <dir holding verify.sh's out/>
# Env:   VERSION (required)
#        NPM_PROVENANCE=false  skip provenance, for a dry run against a local
#                              registry (npm_config_registry) outside Actions
set -euo pipefail

IN=$(cd "${1:?usage: publish.sh <verify output dir>}" && pwd)
: "${VERSION:?VERSION is required}"
[[ $VERSION =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "not a release tag: $VERSION" >&2; exit 1; }
TSVER=$(cat "$IN/version")
[[ v$TSVER == "$VERSION" ]] || { echo "verify packed $TSVER, but the release is $VERSION" >&2; exit 1; }
TGZ=$IN/jennah-sdk-ts-$TSVER.tgz
[[ -f $TGZ ]] || { echo "no tarball at $TGZ" >&2; exit 1; }

# The same Subresource Integrity string npm records for a published tarball.
LOCAL="sha512-$(openssl dgst -sha512 -binary "$TGZ" | base64 | tr -d '\n')"
REMOTE=$(npm view "jennah-sdk-ts@$TSVER" dist.integrity 2>/dev/null || true)
if [[ -n $REMOTE ]]; then
  if [[ $REMOTE == "$LOCAL" ]]; then
    echo "jennah-sdk-ts $TSVER already published with this tarball"
    exit 0
  fi
  echo "jennah-sdk-ts $TSVER already exists on npm with different content; refusing" >&2
  exit 1
fi

flags=(--access public)
[[ ${NPM_PROVENANCE:-true} == false ]] || flags+=(--provenance)
npm publish "$TGZ" "${flags[@]}"
echo "published jennah-sdk-ts $TSVER"
