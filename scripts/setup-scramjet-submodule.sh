#!/usr/bin/env bash
set -euo pipefail

submodule_registered=false
if git config --file .gitmodules --get submodule.vendor/scramjet.path >/dev/null 2>&1; then
  submodule_registered=true
elif git ls-files --error-unmatch vendor/scramjet >/dev/null 2>&1; then
  submodule_registered=true
fi

if [[ "$submodule_registered" == true ]] || [[ -f vendor/scramjet/.git ]] || [[ -d vendor/scramjet/.git ]]; then
  echo "scramjet submodule already configured at vendor/scramjet"
else
  git submodule add https://github.com/MercuryWorkshop/scramjet vendor/scramjet
fi

git submodule update --init --recursive

echo "scramjet submodule initialized recursively."
