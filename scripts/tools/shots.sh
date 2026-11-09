#!/usr/bin/env bash
# Real screenshots without a monitor, so lanes can check their own visuals.
#   scripts/tools/shots.sh [scene.tscn] [times] [out_dir]
#   scripts/tools/shots.sh res://scenes/levels/field.tscn 1,3,6 /tmp/shots
#   SHOTS_ARGS="--demo" scripts/tools/shots.sh "" 3,8,15 /tmp/shots   (extra game args after --)
# Uses `godot-render` (virtual X display + Mesa software Vulkan, Forward+) when it exists, else a real
# display if $DISPLAY/$WAYLAND_DISPLAY is set. Headless Godot has no renderer, so it can't take real shots.
set -euo pipefail
SCENE="${1:-}"; TIMES="${2:-1,3,6}"; OUT="${3:-$PWD/shots}"
mkdir -p "$OUT"
if command -v godot-render >/dev/null; then RUN=godot-render
elif [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then RUN=godot
else echo "shots.sh: no renderer here (no godot-render, no display)" >&2; exit 2; fi
"$RUN" --path . --resolution 1920x1080 ${SCENE:+"$SCENE"} -- --shots="$TIMES" --shot-dir="$OUT" ${SHOTS_ARGS:-} 2>&1 \
  | grep -E "^screenshot:|Forward|Compatibility|SCRIPT ERROR|ERROR" | grep -v fontconfig || true
ls -1 "$OUT"/*.png
