#!/usr/bin/env bash
# Pushes the tree verify.sh tested to jennah-sdk-go main and tags it $VERSION.
#
# Idempotent, because it runs after an irreversible PyPI upload and must be
# safe to re-run until it succeeds:
#   - the tag already exists on the verified tree: nothing to do
#   - the tag exists anywhere else: refuse (a version names one tree, forever)
#   - main already holds the verified tree: tag it without a new commit
#
# It refuses if jennah-sdk-go main moved since verify, because pushing the
# verified tree over a newer main would silently revert whatever landed there.
# Re-run the whole release (delete and re-push the jennah-api tag) instead.
#
# Usage: publish.sh <dir holding verify.sh's out/>
# Env:   DEPLOYER_TOKEN, VERSION (required); SDK_REPO (local override)
set -euo pipefail

IN=$(cd "${1:?usage: publish.sh <verify output dir>}" && pwd)
: "${VERSION:?VERSION is required}"
[[ $VERSION =~ ^v[0-9]+\.[0-9]+\.[0-9]+([-.].+)?$ ]] || { echo "not a semver tag: $VERSION" >&2; exit 1; }
BASE=$(cat "$IN/base")
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
REPO=${SDK_REPO:-https://${DEPLOYER_TOKEN:+$DEPLOYER_TOKEN@}github.com/alphauslabs/jennah-sdk-go}

git clone --quiet "$REPO" "$WORK/sdk"
cd "$WORK/sdk"
git config user.email "dev@mobingi.com"
git config user.name "mobingideployer"

# Rebuild the verified tree in an empty worktree so files the tree lacks are
# removed, not left behind.
git rm -rq --ignore-unmatch . && git clean -fdxq
tar -xzf "$IN/tree.tgz"
git add -A
TREE=$(git write-tree)

if git rev-parse -q --verify "refs/tags/$VERSION" >/dev/null; then
  if [[ $(git rev-parse "$VERSION^{tree}") == "$TREE" ]]; then
    echo "$VERSION already published on the verified tree"
    exit 0
  fi
  echo "$VERSION already exists in jennah-sdk-go on a different tree; refusing" >&2
  exit 1
fi

HEAD=$(git rev-parse HEAD)
if [[ $(git rev-parse "HEAD^{tree}") == "$TREE" ]]; then
  echo "main already holds the verified tree; tagging it"
elif [[ $HEAD == "$BASE" ]]; then
  git commit -q -m "$VERSION from jennah-api ${GITHUB_SHA:-local}"
  git push -q origin HEAD:main
else
  echo "jennah-sdk-go main moved since verify ($BASE -> $HEAD); refusing to push over it" >&2
  exit 1
fi

git tag "$VERSION"
git push -q origin "refs/tags/$VERSION"
echo "published jennah-sdk-go $VERSION at $(git rev-parse HEAD)"
