#!/usr/bin/env bash
# Renders store/clip.mp4 (the launcher's 12 s gameplay clip) from the game itself: a --demo run with
# strong gear (rocket boots run-up, a big kick, the flight past the balloon and clouds, the peak stamp).
# Movie Maker mode renders every frame at a fixed 30 fps whatever the machine, so a software GPU works.
# Needs a renderer (godot-render or a display) and ffmpeg with libx264. Usage: art/tools/make_clip.sh
set -euo pipefail
cd "$(dirname "$0")/../.."
OUT=.scratch/clip
rm -rf "$OUT" && mkdir -p "$OUT"
GODOT=${GODOT:-$(command -v godot-render || command -v godot)}
"$GODOT" --path . --resolution 1920x1080 --write-movie "$PWD/$OUT/f.png" --fixed-fps 30 --quit-after 540 \
	-- --demo --gear=rocket_boots,super_cape,cannon_leg --gear2=jetpack,big_boot,propeller_cap
ffmpeg -hide_banner -loglevel error -y -framerate 30 -start_number 30 -i "$OUT/f%08d.png" -ss 1.0 -i "$OUT/f.wav" \
	-frames:v 360 -t 12 -vf "scale=1280:720:flags=lanczos,format=yuv420p" -c:v libx264 -preset slow -crf 24 \
	-movflags +faststart -c:a aac -b:a 128k -af "afade=t=in:d=0.3,afade=t=out:st=11.4:d=0.6" -shortest store/clip.mp4
echo "wrote store/clip.mp4"
