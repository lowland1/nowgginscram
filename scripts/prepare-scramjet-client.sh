#!/usr/bin/env bash
set -euo pipefail

SCRAMJET_REPO_URL="https://github.com/MercuryWorkshop/scramjet"
SUBMODULE_DIR="vendor/scramjet"
TARGET="scramjet.client.js"

ensure_scramjet_checkout() {
  if [[ -d "$SUBMODULE_DIR" ]]; then
    return
  fi

  echo "[prepare] $SUBMODULE_DIR is missing. Attempting recursive clone from $SCRAMJET_REPO_URL ..."
  mkdir -p "$(dirname "$SUBMODULE_DIR")"
  git clone --recursive "$SCRAMJET_REPO_URL" "$SUBMODULE_DIR"
}

ensure_scramjet_checkout

source_file="$(find "$SUBMODULE_DIR" -type f \( -name 'scramjet.client.js' -o -name 'scramjet.*client*.js' -o -name '*scramjet*client*.js' \) | head -n 1)"

if [[ -z "$source_file" ]]; then
  echo "Could not find a Scramjet client bundle inside $SUBMODULE_DIR." >&2
  exit 1
fi

cp "$source_file" "$TARGET"

echo "Copied $source_file -> $TARGET"
