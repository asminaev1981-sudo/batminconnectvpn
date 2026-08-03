#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENDOR_DIR="$ROOT/vendor/upstream"
SING_BOX_DIR="$VENDOR_DIR/sing-box"

SING_BOX_REPOSITORY="${SING_BOX_REPOSITORY:-https://github.com/SagerNet/sing-box.git}"
SING_BOX_REF="${SING_BOX_REF:-v1.13.12}"

LIBS_DIR="$ROOT/android/app/libs"
OUTPUT="$LIBS_DIR/libbox.aar"
VERSION_FILE="$LIBS_DIR/libbox.version"

log() {
  printf '[libbox-build] %s\n' "$*"
}

fatal() {
  printf '[libbox-build] ERROR: %s\n' "$*" >&2
  exit 1
}

command -v git >/dev/null 2>&1 || fatal "git is required"
command -v go >/dev/null 2>&1 || fatal "Go is required"
command -v gomobile >/dev/null 2>&1 || fatal "gomobile is required"
command -v python3 >/dev/null 2>&1 || fatal "python3 is required"

log "Go: $(go version)"
log "gomobile: $(command -v gomobile)"
log "sing-box ref: $SING_BOX_REF"

mkdir -p "$VENDOR_DIR" "$LIBS_DIR"
rm -rf "$SING_BOX_DIR"

log "Cloning sing-box"
git clone --filter=blob:none "$SING_BOX_REPOSITORY" "$SING_BOX_DIR"
git -C "$SING_BOX_DIR" checkout --detach "$SING_BOX_REF"

cd "$SING_BOX_DIR"

log "Building Android libbox AAR"
go run ./cmd/internal/build_libbox -target android

CANDIDATE="$(
  find "$SING_BOX_DIR" \
    -type f \
    \( -name 'libbox.aar' -o -name 'box.aar' \) \
    -print \
    | head -n 1
)"

if [[ -z "$CANDIDATE" ]]; then
  log "Available AAR files:"
  find "$SING_BOX_DIR" -type f -name '*.aar' -print || true
  fatal "libbox AAR was not produced"
fi

cp -f "$CANDIDATE" "$OUTPUT"

[[ -s "$OUTPUT" ]] || fatal "Generated libbox.aar is empty"

SHA256="$(sha256sum "$OUTPUT" | awk '{print $1}')"
SIZE="$(stat -c '%s' "$OUTPUT")"
COMMIT="$(git -C "$SING_BOX_DIR" rev-parse HEAD)"

cat > "$VERSION_FILE" <<META
repository=$SING_BOX_REPOSITORY
ref=$SING_BOX_REF
commit=$COMMIT
sha256=$SHA256
size=$SIZE
META

printf '%s  %s\n' "$SHA256" "$(basename "$OUTPUT")" > "$OUTPUT.sha256"

log "Created: $OUTPUT"
log "Size: $SIZE bytes"
log "SHA-256: $SHA256"
