#!/usr/bin/env bash
set -euo pipefail

SCRAMJET_REPO_URL="https://github.com/MercuryWorkshop/scramjet"
SUBMODULE_DIR="vendor/scramjet"
TARGET="scramjet.client.js"
WASM_BRIDGE_PATH="$SUBMODULE_DIR/rewriter/wasm/out/wasm.js"

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

ensure_wasm_bridge_stub() {
  if [[ -f "$WASM_BRIDGE_PATH" ]]; then
    return
  fi

  echo "[prepare] Missing $WASM_BRIDGE_PATH; creating temporary compatibility stub."
  mkdir -p "$(dirname "$WASM_BRIDGE_PATH")"
  cat > "$WASM_BRIDGE_PATH" <<'JS'
export function initSync() {
  return;
}

export class Rewriter {
  rewrite(input) {
    return input;
  }
}
JS
}

run_in_scramjet_dir() {
  (
    cd "$SUBMODULE_DIR"
    "$@"
  )
}

run_try() {
  local desc="$1"
  shift
  echo "[prepare] Trying: $desc"
  if ! "$@"; then
    echo "[prepare] Failed: $desc (continuing)" >&2
    return 1
  fi
  return 0
}

has_package_script() {
  local script_name="$1"
  run_in_scramjet_dir node -e "const p=require('./package.json'); process.exit(p.scripts && p.scripts['$script_name'] ? 0 : 1)" >/dev/null 2>&1
}

run_package_script_if_present() {
  local runner="$1"
  local script_name="$2"
  if has_package_script "$script_name"; then
    # shellcheck disable=SC2086
    run_try "$runner $script_name" run_in_scramjet_dir $runner "$script_name" || true
  fi
}

try_build_with_pnpm_runner() {
  local -a pnpm_cmd=("$@")

  run_try "${pnpm_cmd[*]} install --frozen-lockfile" run_in_scramjet_dir "${pnpm_cmd[@]}" install --frozen-lockfile || return

  run_try "${pnpm_cmd[*]} -r --if-present run build" run_in_scramjet_dir "${pnpm_cmd[@]}" -r --if-present run build || true

  if [[ -f "$SUBMODULE_DIR/rewriter/wasm/package.json" ]]; then
    run_try "${pnpm_cmd[*]} -C rewriter/wasm install --frozen-lockfile" run_in_scramjet_dir "${pnpm_cmd[@]}" -C rewriter/wasm install --frozen-lockfile || true
    run_try "${pnpm_cmd[*]} -C rewriter/wasm run build" run_in_scramjet_dir "${pnpm_cmd[@]}" -C rewriter/wasm run build || true
  fi

  run_package_script_if_present "${pnpm_cmd[*]} run" "build:wasm"
  run_package_script_if_present "${pnpm_cmd[*]} run" "build:rewriter"
  run_package_script_if_present "${pnpm_cmd[*]} run" "build:client"
  run_package_script_if_present "${pnpm_cmd[*]} run" "build"
}

try_build_with_npm() {
  run_try "npm install --legacy-peer-deps" run_in_scramjet_dir npm install --legacy-peer-deps || return

  run_package_script_if_present "npm run" "build:wasm"
  run_package_script_if_present "npm run" "build:rewriter"
  run_package_script_if_present "npm run" "build:client"
  run_package_script_if_present "npm run" "build"
}

try_build_scramjet_client() {
  if [[ ! -f "$SUBMODULE_DIR/package.json" ]]; then
    return
  fi

  echo "[prepare] Attempting to build Scramjet client assets from source ..."

  if [[ -f "$SUBMODULE_DIR/pnpm-lock.yaml" ]]; then
    if command -v pnpm >/dev/null 2>&1; then
      try_build_with_pnpm_runner pnpm
      return
    fi

    if command -v corepack >/dev/null 2>&1; then
      try_build_with_pnpm_runner corepack pnpm
      return
    fi

    echo "[prepare] pnpm lockfile found but pnpm/corepack is unavailable." >&2
    return
  fi

  if command -v npm >/dev/null 2>&1; then
    try_build_with_npm
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
ensure_wasm_bridge_stub

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
