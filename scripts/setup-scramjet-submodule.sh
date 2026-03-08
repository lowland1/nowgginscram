#!/usr/bin/env bash
set -euo pipefail

if [[ -d vendor/scramjet/.git ]]; then
  echo "scramjet submodule already exists at vendor/scramjet"
else
  git submodule add https://github.com/MercuryWorkshop/scramjet vendor/scramjet
fi

git submodule update --init --recursive

echo "scramjet submodule initialized recursively."
