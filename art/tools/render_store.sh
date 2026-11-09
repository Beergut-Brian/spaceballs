#!/usr/bin/env bash
# Renders store/grid.png (600x900) and store/hero.png (920x430) from the game's own scenes: the project
# is fullscreen 1920x1080, so each frame is centre-cropped to the target aspect and downsampled (Pillow). Needs a renderer (godot-render or a display), like scripts/tools/shots.sh.
set -euo pipefail
TMP=$(mktemp -d)
RUN=godot-render; command -v godot-render >/dev/null || RUN=godot
"$RUN" --path . --resolution 1920x1080 res://art/preview/store_grid.tscn -- --shots=2 --shot-dir="$TMP/grid" 2>&1 | grep -E "SCRIPT ERROR|^ERROR" || true
"$RUN" --path . --resolution 1920x1080 res://art/preview/store_hero.tscn -- --shots=2 --shot-dir="$TMP/hero" 2>&1 | grep -E "SCRIPT ERROR|^ERROR" || true
python3 - "$TMP" <<'PY'
import sys, glob
from PIL import Image
t = sys.argv[1]
def crop(src, w, h, out):
    im = Image.open(src).convert("RGB")
    W, H = im.size
    if W / H > w / h:
        cw = round(H * w / h); box = ((W - cw) // 2, 0, (W - cw) // 2 + cw, H)
    else:
        ch = round(W * h / w); box = (0, (H - ch) // 2, W, (H - ch) // 2 + ch)
    im.crop(box).resize((w, h), Image.LANCZOS).save(out)
crop(glob.glob(t + "/grid/*.png")[0], 600, 900, "store/grid.png")
crop(glob.glob(t + "/hero/*.png")[0], 920, 430, "store/hero.png")
print("store/grid.png store/hero.png")
PY
rm -rf "$TMP"
