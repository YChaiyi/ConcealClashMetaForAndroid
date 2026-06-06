#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
module_dir="$repo_root/sukisu-module"
out_dir="$repo_root/build/root-module"
out_zip="$out_dir/conceal-cmfa-root-proxy.zip"

mkdir -p "$out_dir"
rm -f "$out_zip"

(cd "$module_dir" && zip -r "$out_zip" . -x '*.DS_Store' 'cmfa-root.log' >/dev/null)

echo "$out_zip"
