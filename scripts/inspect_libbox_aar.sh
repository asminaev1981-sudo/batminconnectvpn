#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AAR="$ROOT/android/app/libs/libbox.aar"
[[ -f "$AAR" ]] || { echo "Missing $AAR" >&2; exit 1; }
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
unzip -q "$AAR" -d "$TMP"
[[ -f "$TMP/classes.jar" ]] || { echo "AAR has no classes.jar" >&2; exit 1; }
jar tf "$TMP/classes.jar" | grep -E '(^|/)libbox/|Libbox|PlatformInterface|BoxService' | sort
