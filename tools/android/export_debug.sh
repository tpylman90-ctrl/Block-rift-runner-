#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"
mkdir -p "$ROOT/build"

if [[ ! -f "$ROOT/android/debug.keystore" ]]; then
  base64 --decode "$ROOT/android/debug.keystore.base64" > "$ROOT/android/debug.keystore"
fi

"$GODOT_BIN" --headless --path "$ROOT" \
  --export-debug Android "$ROOT/build/BlockRiftRunner.apk"

printf 'APK created: %s\n' "$ROOT/build/BlockRiftRunner.apk"

