#!/usr/bin/env bash
# Render the 44 upgrade card icons into assets/sprites/upgrades/ (512x512 PNG).
#   art/tools/render_icons.sh              all 44 (about 5 minutes on CPU)
#   art/tools/render_icons.sh big_boot,sneeze   only these
# Step 1 (Blender, Cycles): art/tools/render_icons.py renders each gear glb or vignette on a transparent studio.
# Step 2 (Pillow): art/tools/icon_post.py fits, outlines and shadows them. Raw renders go to $ICON_RAW.
set -euo pipefail
cd "$(dirname "$0")/../.."
RAW="${ICON_RAW:-.scratch/icons_raw}"
ONLY="${1:-}"
blender -b --factory-startup -P art/tools/render_icons.py -- --raw "$RAW" ${ONLY:+--only "$ONLY"} \
	${ICON_SAMPLES:+--samples "$ICON_SAMPLES"} 2>&1 | grep -E "^ICON|Error|Traceback|^  File|Exception" || true
python3 art/tools/icon_post.py "$RAW" assets/sprites/upgrades ${ONLY:+--only "$ONLY"}
