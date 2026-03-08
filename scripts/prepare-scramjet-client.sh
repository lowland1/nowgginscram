#!/usr/bin/env bash
set -euo pipefail

SUBMODULE_DIR="vendor/scramjet"
TARGET="scramjet.client.js"

if [[ ! -d "$SUBMODULE_DIR" ]]; then
  echo "Missing $SUBMODULE_DIR. Run git submodule update --init --recursive first." >&2
  exit 1
fi

source_file="$(find "$SUBMODULE_DIR" -type f \( -name 'scramjet.client.js' -o -name 'scramjet.*client*.js' -o -name '*scramjet*client*.js' \) | head -n 1)"

if [[ -z "$source_file" ]]; then
  echo "Could not find a Scramjet client bundle inside $SUBMODULE_DIR." >&2
  exit 1
fi

cp "$source_file" "$TARGET"

echo "Copied $source_file -> $TARGET"
