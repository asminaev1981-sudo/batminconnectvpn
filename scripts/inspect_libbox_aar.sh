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

echo "===== LIBBOX CLASSES ====="
jar tf "$TMP/classes.jar" \
    | grep -E '(^|/)libbox/|Libbox|PlatformInterface|BoxService|TunOptions|CommandClientOptions|SetupOptions' \
    | sort

inspect_class() {
    local class="$1"

    echo
    echo "===== $class ====="

    if javap -classpath "$TMP/classes.jar" -public "$class"; then
        true
    else
        echo "CLASS NOT FOUND: $class"
    fi
}

inspect_class io.nekohasekai.libbox.Libbox
inspect_class io.nekohasekai.libbox.PlatformInterface
inspect_class io.nekohasekai.libbox.TunOptions
inspect_class io.nekohasekai.libbox.CommandClientOptions
inspect_class io.nekohasekai.libbox.SetupOptions

echo
echo "===== INSPECTION COMPLETE ====="
