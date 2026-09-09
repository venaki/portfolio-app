#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
target="${1:-all}"
if [[ $# -gt 1 || ! "$target" =~ ^(all|firebase|github)$ ]]; then
  echo "Usage: scripts/build_web.sh [all|firebase|github]" >&2
  exit 2
fi
cd "$project_root"

flutter pub get --enforce-lockfile

build_target() {
  local hosting_target="$1"
  local base_href="$2"
  local output_dir="$project_root/build/hosting/$hosting_target"
  flutter build web --release --no-pub \
    --dart-define=DEV_MODE=false \
    --base-href="$base_href" \
    --output="$output_dir"

  python3 - "$output_dir/index.html" "$base_href" <<'PY'
import pathlib
import sys

index = pathlib.Path(sys.argv[1])
expected = f'<base href="{sys.argv[2]}">'
if expected not in index.read_text():
    raise SystemExit(f"Unexpected base href in {index}; expected {expected}")
if not index.with_name('main.dart.js').is_file():
    raise SystemExit(f"Missing JavaScript bundle beside {index}")
PY
  if [[ "$hosting_target" == github ]]; then
    touch "$output_dir/.nojekyll"
  fi
  echo "Built $hosting_target: $output_dir (base: $base_href)"
}

if [[ "$target" == all || "$target" == firebase ]]; then
  build_target firebase /
fi
if [[ "$target" == all || "$target" == github ]]; then
  build_target github /portfolio-app/
fi
