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

ensure_nested_submodules() {
  if [[ ! -d "$SUBMODULE_DIR/.git" && ! -f "$SUBMODULE_DIR/.git" ]]; then
    return
  fi

  echo "[prepare] Ensuring nested submodules are initialized in $SUBMODULE_DIR ..."
  (
    cd "$SUBMODULE_DIR"
    git submodule update --init --recursive || true
  )
}

run_in_scramjet_dir() {
  (
    cd "$SUBMODULE_DIR"
    "$@"
  )
}

has_package_script() {
  local script_name="$1"
  run_in_scramjet_dir node -e "const p=require('./package.json'); process.exit(p.scripts && p.scripts['$script_name'] ? 0 : 1)" >/dev/null 2>&1
}

run_package_script_if_present() {
  local run_cmd="$1"
  local script_name="$2"
  if has_package_script "$script_name"; then
    echo "[prepare] Running $run_cmd $script_name ..."
    if ! run_in_scramjet_dir $run_cmd "$script_name"; then
      echo "[prepare] $run_cmd $script_name failed; continuing with other strategies." >&2
      return 1
    fi
  fi
  return 0
}

try_build_scramjet_client() {
  if [[ ! -f "$SUBMODULE_DIR/package.json" ]]; then
    return
  fi

  echo "[prepare] Attempting to build Scramjet client assets from source ..."

  if [[ -f "$SUBMODULE_DIR/pnpm-lock.yaml" ]]; then
    if command -v pnpm >/dev/null 2>&1; then
      if ! run_in_scramjet_dir pnpm install --frozen-lockfile; then
        echo "[prepare] pnpm install failed; skipping pnpm build path." >&2
        return
      fi

      run_package_script_if_present "pnpm run" "build:wasm" || true
      run_package_script_if_present "pnpm run" "build:rewriter" || true
      run_package_script_if_present "pnpm run" "build" || true
      return
    fi

    if command -v corepack >/dev/null 2>&1; then
      if ! run_in_scramjet_dir corepack pnpm install --frozen-lockfile; then
        echo "[prepare] corepack pnpm install failed; skipping pnpm build path." >&2
        return
      fi

      run_package_script_if_present "corepack pnpm run" "build:wasm" || true
      run_package_script_if_present "corepack pnpm run" "build:rewriter" || true
      run_package_script_if_present "corepack pnpm run" "build" || true
      return
    fi

    echo "[prepare] pnpm lockfile found but pnpm/corepack is unavailable." >&2
    return
  fi

  if command -v npm >/dev/null 2>&1; then
    if ! run_in_scramjet_dir npm install --legacy-peer-deps; then
      echo "[prepare] npm install failed; skipping npm build path." >&2
      return
    fi

    run_package_script_if_present "npm run" "build:wasm" || true
    run_package_script_if_present "npm run" "build:rewriter" || true
    run_package_script_if_present "npm run" "build" || true
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
ensure_nested_submodules

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
