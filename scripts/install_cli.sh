#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DART_BIN="${DART_BIN:-dart}"
DEST="${1:-$HOME/.local/bin}"
cd "$ROOT/cli"
"$DART_BIN" pub get --enforce-lockfile
"$DART_BIN" analyze
"$DART_BIN" test
mkdir -p "$ROOT/build/cli" "$DEST"
"$DART_BIN" compile exe bin/portfolio.dart -o "$ROOT/build/cli/portfolio"
install -m 755 "$ROOT/build/cli/portfolio" "$DEST/portfolio"
printf 'Installed: %s/portfolio\n' "$DEST"
