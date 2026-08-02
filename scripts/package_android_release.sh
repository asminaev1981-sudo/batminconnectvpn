#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MODE="${1:-debug}"
VERSION="$(awk '/^version:/ {print $2}' "$ROOT/pubspec.yaml" | tr '+' '-')"
DIST="$ROOT/dist"
STAGE="$DIST/Batmin_Connect_${VERSION}_${MODE}"

case "$MODE" in
  debug) APK="$ROOT/build/app/outputs/flutter-apk/app-debug.apk" ;;
  release) APK="$ROOT/build/app/outputs/flutter-apk/app-release.apk" ;;
  *) echo "Usage: $0 [debug|release]" >&2; exit 2 ;;
esac

[[ -f "$APK" ]] || { echo "APK not found: $APK" >&2; exit 1; }
rm -rf "$STAGE"
mkdir -p "$STAGE" "$DIST"
cp "$APK" "$STAGE/Batmin-Connect-${MODE}.apk"
cp "$ROOT/CHANGELOG.md" "$STAGE/CHANGELOG.md"
cp "$ROOT/docs/INSTALL.md" "$STAGE/INSTALL.md"
cp "$ROOT/docs/RELEASE_STATUS.md" "$STAGE/RELEASE_STATUS.md"
if [[ -f "$ROOT/android/app/libs/libbox.version" ]]; then
  cp "$ROOT/android/app/libs/libbox.version" "$STAGE/libbox.version"
fi
(
  cd "$STAGE"
  sha256sum "Batmin-Connect-${MODE}.apk" > SHA256.txt
)
ARCHIVE="$DIST/$(basename "$STAGE").zip"
rm -f "$ARCHIVE" "$ARCHIVE.sha256"
(
  cd "$DIST"
  zip -qr "$(basename "$ARCHIVE")" "$(basename "$STAGE")"
  sha256sum "$(basename "$ARCHIVE")" > "$(basename "$ARCHIVE").sha256"
)
echo "Created: $ARCHIVE"
