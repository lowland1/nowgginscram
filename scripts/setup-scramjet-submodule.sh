#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

submodule_path="vendor/scramjet"
submodule_name="vendor/scramjet"
submodule_url="https://github.com/MercuryWorkshop/scramjet"

submodule_registered=false
if git config --file "$repo_root/.gitmodules" --get "submodule.${submodule_name}.path" >/dev/null 2>&1; then
  submodule_registered=true
elif git config --get "submodule.${submodule_name}.url" >/dev/null 2>&1; then
  submodule_registered=true
elif git ls-files --error-unmatch "$submodule_path" >/dev/null 2>&1; then
  submodule_registered=true
fi

if [[ "$submodule_registered" == true ]] || [[ -f "$submodule_path/.git" ]] || [[ -d "$submodule_path/.git" ]]; then
  echo "scramjet submodule already configured at $submodule_path"
else
  git submodule add "$submodule_url" "$submodule_path"
fi

git submodule update --init --recursive

echo "scramjet submodule initialized recursively."
