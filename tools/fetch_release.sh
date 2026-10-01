#!/usr/bin/env bash
set -euo pipefail

test -f ~/.bashrc && {
    echo "Loading Github token from bashrc"
    . ~/.bashrc
}

OWNER="$1"
REPO="$2"
TAG="$3"
ASSET="$4"

CACHE_BASE="${XDG_CACHE_HOME:-$HOME/.cache}/github-releases"
CACHE_DIR="$CACHE_BASE/$OWNER/$REPO/$TAG"
FILE="$CACHE_DIR/$ASSET"

mkdir -p "$CACHE_DIR"

if [[ -f "$FILE" ]]; then
  echo "✔ cache hit: $FILE"
  exit 0
fi

echo "⬇ cache miss, downloading…"

gh release download "$TAG" \
  -R "$OWNER/$REPO" \
  -p "$ASSET" \
  -D "$CACHE_DIR" && echo "✔ Download finished"
