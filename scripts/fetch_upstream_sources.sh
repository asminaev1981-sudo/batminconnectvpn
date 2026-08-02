#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/vendor/upstream"
cd "$ROOT/vendor/upstream"

if [ ! -d sing-box-for-android ]; then
  git clone https://github.com/SagerNet/sing-box-for-android.git
fi
if [ ! -d sing-box ]; then
  git clone https://github.com/SagerNet/sing-box.git
fi

echo "Upstream sources downloaded. Pin exact revisions before production use."
