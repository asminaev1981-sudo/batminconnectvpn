#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AAR="$ROOT/android/app/libs/libbox.aar"

[[ -f "$AAR" ]] || {
    echo "Missing $AAR" >&2
    exit 1
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

unzip -q "$AAR" -d "$TMP"

[[ -f "$TMP/classes.jar" ]] || {
    echo "AAR has no classes.jar" >&2
    exit 1
}

CLASSES="$TMP/classes.jar"

echo "===== LIBBOX CLASSES ====="
jar tf "$CLASSES" | grep '^io/nekohasekai/libbox/.*\.class$' | sort

inspect() {
    echo
    echo "===== $1 ====="
    javap -classpath "$CLASSES" -public "$1" || true
}

inspect io.nekohasekai.libbox.PlatformInterface
inspect io.nekohasekai.libbox.Libbox
inspect io.nekohasekai.libbox.OverrideOptions
