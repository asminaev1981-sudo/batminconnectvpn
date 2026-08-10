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

inspect io.nekohasekai.libbox.Libbox
inspect io.nekohasekai.libbox.PlatformInterface
inspect io.nekohasekai.libbox.TunOptions
inspect io.nekohasekai.libbox.SetupOptions

inspect io.nekohasekai.libbox.CommandServer
inspect io.nekohasekai.libbox.CommandServerHandler
inspect io.nekohasekai.libbox.CommandClient
inspect io.nekohasekai.libbox.CommandClientHandler
inspect io.nekohasekai.libbox.CommandClientOptions

inspect io.nekohasekai.libbox.NetworkInterface
inspect io.nekohasekai.libbox.NetworkInterfaceIterator
inspect io.nekohasekai.libbox.RoutePrefix
inspect io.nekohasekai.libbox.RoutePrefixIterator
inspect io.nekohasekai.libbox.StringBox
inspect io.nekohasekai.libbox.StringIterator
inspect io.nekohasekai.libbox.InterfaceUpdateListener
inspect io.nekohasekai.libbox.ConnectionOwner
inspect io.nekohasekai.libbox.LocalDNSTransport
inspect io.nekohasekai.libbox.Notification
inspect io.nekohasekai.libbox.WIFIState
inspect io.nekohasekai.libbox.AndroidVPNType

echo
echo "===== INSPECTION COMPLETE ====="
