#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dist_dir="$project_dir/dist"
if [[ "$dist_dir" != "$project_dir/dist" ]]; then
  echo "Refusing to clean an unexpected export path" >&2
  exit 1
fi
mkdir -p "$dist_dir"
find "$dist_dir" -mindepth 1 -maxdepth 1 -delete
godot --headless --path "$project_dir" --export-release Web "$dist_dir/index.html"

required=(index.html index.js index.wasm index.pck)
for file in "${required[@]}"; do
  if [[ ! -s "$dist_dir/$file" ]]; then
    echo "Missing export artifact: dist/$file" >&2
    exit 1
  fi
done

echo "PETRI web export ready in $dist_dir"
