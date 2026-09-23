#!/usr/bin/env bash
# Runs the cross-language session tests against a jennah-sdk-go tree and a
# jennah-sdk-py distribution, normally the two that verify just tested.
#
# Usage: run.sh <jennah-sdk-go dir or verify's tree.tgz> <jennah-sdk-py dist dir or source dir>
#   A dist dir installs its wheel into a fresh venv (CI). A source dir is put on
#   PYTHONPATH as-is, for running locally against an assembled checkout, in which
#   case grpcio, protobuf, googleapis-common-protos and pytest must already be
#   importable.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
GO_IN=${1:?usage: run.sh <sdk-go dir|tree.tgz> <sdk-py dist|source dir>}
PY_IN=$(cd "${2:?usage: run.sh <sdk-go dir|tree.tgz> <sdk-py dist|source dir>}" && pwd)
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
