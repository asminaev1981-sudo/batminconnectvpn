#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VENDOR_DIR="${BATMIN_VENDOR_DIR:-$ROOT/vendor/upstream}"
SING_BOX_DIR="$VENDOR_DIR/sing-box"
# Stable pin used by this integration package. Override only deliberately.
SING_BOX_REF="${SING_BOX_REF:-v1.13.12}"
OUTPUT="$ROOT/android/app/libs/libbox.aar"

command -v git >/dev/null || { echo "git is required" >&2; exit 1; }
command -v go >/dev/null || { echo "Go is required" >&2; exit 1; }

mkdir -p "$VENDOR_DIR" "$(dirname "$OUTPUT")"
if [[ ! -d "$SING_BOX_DIR/.git" ]]; then
  git clone https://github.com/SagerNet/sing-box.git "$SING_BOX_DIR"
fi

git -C "$SING_BOX_DIR" fetch --tags --force
git -C "$SING_BOX_DIR" checkout --detach "$SING_BOX_REF"

(
  cd "$SING_BOX_DIR"
  python3 <<'PATCH'
from pathlib import Path

p = Path("cmd/internal/build_libbox/main.go")
t = p.read_text()

t = t.replace("-libname=box,", "")
t = t.replace("-libname=box", "")
t = t.replace("-buildvcs=false", "")

p.write_text(t)

print("Removed obsolete gomobile flags")
PATCH

go get -tool golang.org/x/mobile/cmd/gobind
go mod tidy

go run ./cmd/internal/build_libbox -target android
)

CANDIDATE="$(find "$SING_BOX_DIR" -type f -name 'libbox.aar' -print -quit)"
if [[ -z "$CANDIDATE" ]]; then
  echo "libbox.aar was not produced" >&2
  exit 1
fi
cp "$CANDIDATE" "$OUTPUT"
sha256sum "$OUTPUT" | tee "$OUTPUT.sha256"
cat > "$ROOT/android/app/libs/libbox.version" <<META
source=https://github.com/SagerNet/sing-box
ref=$SING_BOX_REF
commit=$(git -C "$SING_BOX_DIR" rev-parse HEAD)
sha256=$(sha256sum "$OUTPUT" | awk '{print $1}')
META

echo "Created: $OUTPUT"
