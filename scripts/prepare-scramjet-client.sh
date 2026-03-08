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

run_in_scramjet_dir() {
  (
    cd "$SUBMODULE_DIR"
    "$@"
  )
}

try_build_scramjet_client() {
  if [[ ! -f "$SUBMODULE_DIR/package.json" ]]; then
    return
  fi

  echo "[prepare] Attempting to build Scramjet client assets from source ..."

  if [[ -f "$SUBMODULE_DIR/pnpm-lock.yaml" ]]; then
    if command -v pnpm >/dev/null 2>&1; then
      run_in_scramjet_dir pnpm install --frozen-lockfile
      run_in_scramjet_dir pnpm run build
      return
    fi

    if command -v corepack >/dev/null 2>&1; then
      run_in_scramjet_dir corepack pnpm install --frozen-lockfile
      run_in_scramjet_dir corepack pnpm run build
      return
    fi

    echo "[prepare] pnpm lockfile found but pnpm/corepack is unavailable." >&2
    return
  fi

  if command -v npm >/dev/null 2>&1; then
    run_in_scramjet_dir npm install --legacy-peer-deps
    run_in_scramjet_dir npm run build
  fi
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
