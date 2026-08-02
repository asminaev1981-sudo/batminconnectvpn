#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
python3 "$ROOT/tools/validate_profile.py"
for f in pubspec.yaml android/app/src/main/AndroidManifest.xml android/app/src/main/kotlin/pro/batmin/connect/BatminVpnService.kt; do
  test -f "$ROOT/$f" || { echo "Missing: $f"; exit 1; }
done
if [ -f "$ROOT/vendor/libbox.aar" ]; then
  echo "libbox.aar: present"
else
  echo "libbox.aar: MISSING (independent VPN runtime is not yet available)"
fi
