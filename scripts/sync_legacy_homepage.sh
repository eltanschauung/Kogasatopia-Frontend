#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source_dir="$repo_root/priv/legacy_site/home/includes"
target_dir="${1:-$source_dir}"

install -d "$target_dir"
for file in blog.html navBar.html panels.html panels_mobile.html tabs.html; do
  install -m 0644 "$source_dir/$file" "$target_dir/$file"
done

echo "Synced legacy homepage fragments to $target_dir"
