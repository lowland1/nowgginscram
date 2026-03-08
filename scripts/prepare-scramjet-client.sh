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

try_build_scramjet_client() {
  if [[ ! -f "$SUBMODULE_DIR/package.json" ]]; then
    return
  fi

  if ! command -v npm >/dev/null 2>&1; then
    return
  fi

  echo "[prepare] Attempting to build Scramjet client assets from source ..."
  (
    cd "$SUBMODULE_DIR"
    npm install
    npm run build || true
  )
}

find_scramjet_client_file() {
  find "$SUBMODULE_DIR" -type f \( \
    -name 'scramjet.client.js' -o \
    -name 'scramjet.*client*.js' -o \
    -name '*scramjet*client*.js' -o \
    -name '*client*.js' -o \
    -name '*.bundle.js' \
  \) | while read -r file; do
    if grep -qE '__scramjet\$rewriteUrl|rewriteUrl' "$file" 2>/dev/null; then
      echo "$file"
      return 0
    fi
  done
}

ensure_scramjet_checkout

source_file="$(find_scramjet_client_file | head -n 1 || true)"

if [[ -z "$source_file" ]]; then
  try_build_scramjet_client
  source_file="$(find_scramjet_client_file | head -n 1 || true)"
fi

if [[ -z "$source_file" ]]; then
  echo "Could not find or build a Scramjet client bundle inside $SUBMODULE_DIR." >&2
  exit 1
fi

cp "$source_file" "$TARGET"

echo "Copied $source_file -> $TARGET"
