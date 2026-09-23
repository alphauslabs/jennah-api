#!/usr/bin/env bash
# Assembles jennah-sdk-py from its current main plus this revision's generated
# code and conformance suite (assemble.sh), tests it, and builds the
# distributions. On success, out/dist holds exactly what the publish job
# uploads to PyPI.
#
# Env:
#   DEPLOYER_TOKEN  GitHub token able to read the SDK repo (optional if public)
#   VERSION         the release tag (v1.2.3), or empty for a non-release build
#   SDK_REPO        override the clone source, for running this locally
set -euo pipefail

ROOT=$PWD
OUT=$ROOT/out
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
REPO=${SDK_REPO:-https://${DEPLOYER_TOKEN:+$DEPLOYER_TOKEN@}github.com/alphauslabs/jennah-sdk-py}

rm -rf "$OUT" && mkdir -p "$OUT"
if ! git clone --quiet "$REPO" "$WORK/sdk"; then
  echo "cannot clone jennah-sdk-py from $REPO: every release publishes every language, so a missing SDK fails the release" >&2
  exit 1
fi
git -C "$WORK/sdk" rev-parse HEAD >"$OUT/base"
PYVER=$("$ROOT/ci/python/assemble.sh" "$WORK/sdk")
cd "$WORK/sdk"

python -m venv "$WORK/venv"
# shellcheck disable=SC1091
source "$WORK/venv/bin/activate"
python -m pip install --quiet --upgrade pip build
python -m pip install --quiet -e '.[test]'
# Includes the conformance harness: the shared suite gates the release.
python -m pytest -q

python -m build --outdir "$OUT/dist"
# Guard against a pyproject.toml that ignores _version.py.
ls "$OUT/dist" | grep -q -- "-$PYVER[-.]" || { echo "built distributions do not carry version $PYVER:" >&2; ls "$OUT/dist" >&2; exit 1; }
echo "jennah-sdk-py $PYVER verified on $(cat "$OUT/base")"
