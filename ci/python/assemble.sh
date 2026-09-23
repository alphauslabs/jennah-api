#!/usr/bin/env bash
# Lays this revision's generated Python code, conformance suite and version
# file over a jennah-sdk-py checkout. Used by verify.sh in CI, and by
# jennah-sdk-py's scripts/dev-generate.sh locally, so both assemble the SDK the
# same way. Run `buf generate` in jennah-api first.
#
# Layout this expects of jennah-sdk-py (the counterpart of jennah-sdk-go's
# hand-written root package over a generated jennah/ subtree):
#   src/jennah/*.py          hand-written SDK, flat: every subdirectory of
#                            src/jennah is a generated proto package
#   src/jennah/_version.py   written here; pyproject.toml reads the version from it
#   src/gnostic/             generated (a proto dependency with no PyPI package)
#   conformance/             copied here; the Python harness reads it
#   pyproject.toml           a "test" extra; protobuf runtime >= the gencode
#                            version pinned in buf.gen.yaml; googleapis-common-protos
#                            for google.api
#
# Generated code is not committed to jennah-sdk-py. It exists in the published
# distributions only, so the repository cannot drift from the proto it claims.
#
# Usage: assemble.sh <jennah-sdk-py dir>
# Env:   VERSION  the release tag (v1.2.3), or empty for a non-release build
set -euo pipefail

API=$(cd "$(dirname "$0")/../.." && pwd)
SDK=$(cd "${1:?usage: assemble.sh <jennah-sdk-py dir>}" && pwd)
GEN=$API/generated/python
[[ -d $GEN/jennah ]] || { echo "no generated Python in $GEN: run buf generate in jennah-api" >&2; exit 1; }

# PEP 440: v1.2.3 publishes as 1.2.3. A non-release build gets a dev version
# that PyPI would never be asked to accept.
if [[ -n ${VERSION:-} ]]; then
  [[ $VERSION =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "not a release tag: $VERSION" >&2; exit 1; }
  PYVER=${VERSION#v}
else
  PYVER=0.0.0.dev0
fi

cd "$SDK"
# Generated packages are replaced wholesale, so a proto package that was removed
# disappears instead of lingering in the wheel.
generated=(src/gnostic)
for dir in "$GEN"/jennah/*/; do
  generated+=("src/jennah/$(basename "$dir")")
done
rm -rf "${generated[@]}"
mkdir -p src/jennah
cp -r "$GEN"/jennah/* src/jennah/
cp -r "$GEN/gnostic" src/
# protoc emits modules, not packages.
find "${generated[@]}" -type d | while IFS= read -r d; do
  [[ -f $d/__init__.py ]] || : >"$d/__init__.py"
done

rm -rf conformance && cp -r "$API/conformance" .

cat >src/jennah/_version.py <<EOF
# Written by jennah-api ci/python/assemble.sh; not committed.
__version__ = "$PYVER"
__source_commit__ = "$(git rev-parse HEAD 2>/dev/null || echo unknown)"
EOF
echo "$PYVER"
