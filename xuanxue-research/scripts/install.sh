#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENDOR="$ROOT/vendor/ziwei-doushu"

if [[ ! -d "$VENDOR/.git" ]]; then
  git clone --depth 1 https://github.com/Renhuai123/ziwei-doushu.git "$VENDOR"
fi

cd "$VENDOR"
npm install --no-audit --no-fund

echo "ziwei-doushu ready at $VENDOR"
