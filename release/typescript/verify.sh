#!/usr/bin/env bash
# Assembles jennah-sdk-ts from its current main plus this revision's generated
# code and conformance suite (assemble.sh), type-checks and tests it, and packs
# the tarball. On success, out/ holds exactly what the publish job uploads to
# npm: the tarball, its version, and the SDK commit it was built on.
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
REPO=${SDK_REPO:-https://${DEPLOYER_TOKEN:+$DEPLOYER_TOKEN@}github.com/alphauslabs/jennah-sdk-ts}

rm -rf "$OUT" && mkdir -p "$OUT"
if ! git clone --quiet "$REPO" "$WORK/sdk"; then
  echo "cannot clone jennah-sdk-ts from $REPO: every release publishes every language, so a missing SDK fails the release" >&2
  exit 1
fi
git -C "$WORK/sdk" rev-parse HEAD >"$OUT/base"
TSVER=$("$ROOT/release/typescript/assemble.sh" "$WORK/sdk")
cd "$WORK/sdk"

npm ci --no-audit --no-fund
npm run typecheck
# Includes the conformance harness and the classification guard: the shared
# suite gates the release.
npm test

npm pack --pack-destination "$OUT" >/dev/null
TGZ=$OUT/jennah-sdk-ts-$TSVER.tgz
# Guard against a package.json the version stamp did not reach.
[[ -f $TGZ ]] || { echo "packed tarball does not carry version $TSVER:" >&2; ls "$OUT" >&2; exit 1; }
field() { tar -xzOf "$TGZ" package/package.json | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{let v=JSON.parse(s);for(const k of process.argv[1].split("."))v=v?.[k];console.log(v??"")})' "$1"; }
PACKED=$(field version)
[[ $PACKED == "$TSVER" ]] || { echo "packed package.json says $PACKED, want $TSVER" >&2; exit 1; }
# npm rejects a trusted publish whose repository.url is not the repository that
# built it, and it would do so only after PyPI had published. Catch it here,
# before any publish step runs.
if [[ -n ${VERSION:-} && -n ${GITHUB_REPOSITORY:-} ]]; then
  REPO_URL=$(field repository.url)
  [[ $REPO_URL == "git+https://github.com/$GITHUB_REPOSITORY.git" ]] ||
    { echo "packed repository.url is $REPO_URL, but npm provenance requires github.com/$GITHUB_REPOSITORY" >&2; exit 1; }
fi
echo "$TSVER" >"$OUT/version"
echo "jennah-sdk-ts $TSVER verified on $(cat "$OUT/base")"
