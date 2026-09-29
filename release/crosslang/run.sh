#!/usr/bin/env bash
# Runs the cross-language session tests against a jennah-sdk-go tree, a
# jennah-sdk-py distribution and a jennah-sdk-ts tarball, normally the three
# that verify just tested.
#
# Usage: run.sh <sdk-go dir or tree.tgz> <sdk-py dist dir or source dir> <sdk-ts out dir or source dir>
#   A Python dist dir installs its wheel into a fresh venv (CI). A source dir is
#   put on PYTHONPATH as-is, for running locally against an assembled checkout,
#   in which case grpcio, protobuf, googleapis-common-protos and pytest must
#   already be importable.
#   A TypeScript dir holding a .tgz (verify's out/) installs that tarball; any
#   other dir must be an assembled, built checkout (dist/ present) and is
#   installed from as-is.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
GO_IN=${1:?usage: run.sh <sdk-go dir|tree.tgz> <sdk-py dist|source dir> <sdk-ts out|source dir>}
PY_IN=$(cd "${2:?usage: run.sh <sdk-go dir|tree.tgz> <sdk-py dist|source dir> <sdk-ts out|source dir>}" && pwd)
TS_IN=$(cd "${3:?usage: run.sh <sdk-go dir|tree.tgz> <sdk-py dist|source dir> <sdk-ts out|source dir>}" && pwd)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

if [[ -f $GO_IN ]]; then
  mkdir "$WORK/sdk-go" && tar -xzf "$GO_IN" -C "$WORK/sdk-go"
  GO_DIR=$WORK/sdk-go
else
  GO_DIR=$(cd "$GO_IN" && pwd)
fi

# Build the helper against exactly that tree.
cp -r "$HERE/gohelper" "$WORK/gohelper"
cd "$WORK/gohelper"
cat >go.mod <<EOF
module crosslang/gohelper

go 1.26.4

require github.com/alphauslabs/jennah-sdk-go v0.0.0

replace github.com/alphauslabs/jennah-sdk-go => $GO_DIR
EOF
go mod tidy
go build -o "$WORK/gohelper-bin" .
export GOHELPER=$WORK/gohelper-bin

# Install the TypeScript helper against exactly that package.
mkdir "$WORK/tshelper"
cp "$HERE/tshelper/tshelper.mjs" "$WORK/tshelper/"
TS_PKG=$(compgen -G "$TS_IN/jennah-sdk-ts-*.tgz" | head -1 || true)
[[ -n $TS_PKG ]] || { [[ -d $TS_IN/dist ]] && TS_PKG=$TS_IN; } || { echo "no jennah-sdk-ts tarball or built checkout in $TS_IN" >&2; exit 1; }
(cd "$WORK/tshelper" && echo '{"type":"module","private":true}' >package.json && npm install --no-audit --no-fund --silent "$TS_PKG")
export TSHELPER=$WORK/tshelper/tshelper.mjs

cd "$HERE"
if compgen -G "$PY_IN/*.whl" >/dev/null; then
  python -m venv "$WORK/venv"
  # shellcheck disable=SC1091
  source "$WORK/venv/bin/activate"
  python -m pip install --quiet "$PY_IN"/*.whl pytest
  python -m pytest -q -p no:cacheprovider test_crosslang.py
else
  PYTHONPATH="$PY_IN/src${PYTHONPATH:+:$PYTHONPATH}" \
    python3 -m pytest -q -p no:cacheprovider test_crosslang.py
fi
