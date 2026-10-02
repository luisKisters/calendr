#!/bin/bash
# The polished walkthrough: the app records itself (2x, 60 fps, no overlays) with cursor telemetry and captions,
# Glide renders it (backdrop, rounded window, cursor, auto-zoom), scripts/caption-video.py burns the caption chips.
# Usage: scripts/walkthrough-video.sh [--skip-build]     Output: artifacts/walkthrough-v3.mp4
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH="$HOME/.local/bin:$PATH"
command -v glide >/dev/null || { echo "glide not found (https://glide.dipxsy.app)"; exit 1; }
REC=artifacts/walkthrough-v3.mov
TMP=artifacts/tmp/walkthrough-v3.glide.mp4
mkdir -p artifacts/tmp

[ "${1:-}" = "--skip-build" ] || scripts/build-app.sh 2>&1 | tail -2
build/Calendr.app/Contents/MacOS/Calendr --walkthrough --record "$REC" | tail -4
rm -f artifacts/walkthrough-v3.mov.sb-*

echo "== glide inspect (video, telemetry and the auto-zoom regions Glide would pick; replaced by the explicit regions below)"
glide inspect --zoom-scale 1.45 "$REC" | python3 -c '
import json, sys
d = json.load(sys.stdin)
print("video %sx%s, %.1f s, %d cursor samples, %d clicks" % (d["video"]["width"], d["video"]["height"], d["video"]["duration"], d["telemetry"]["samples"], d["telemetry"]["clicks"]))
for r in d["autoZoomRegions"]: print("  zoom %.2f-%.2f s  x%.2f at (%.2f, %.2f)" % (r["start"], r["end"], r["scale"], r["x"], r["y"]))'

# Auto-zoom follows every click and is too busy for a fast tour: the tour writes the 7 moments that matter (<file>.zoom.json)
# and they are passed as explicit regions. Glide's camera starts on the cursor and follows it, so the tour moves the cursor to where the action is.
ZOOM_ARGS=()
while IFS= read -r r; do ZOOM_ARGS+=(--zoom-region "$r"); done < <(python3 -c '
import json, sys
for z in json.load(open(sys.argv[1])): print("%.2f-%.2f:1.45" % (z["start"], z["end"]))' "$REC.zoom.json")
echo "== zoom regions used"; printf '  %s\n' "${ZOOM_ARGS[@]:-none}" | grep -v -- --zoom-region

glide render "$REC" -o "$TMP" \
  "${ZOOM_ARGS[@]}" \
  --background gradient:#17161d,#0b0b0e,155 --padding 10 --radius 16 --shadow 0.6 \
  --resolution 1080p --quality high --zoom-scale 1.45 \
  --fps 60 --cursor-motion fast --cursor-size 3 --click-effect on \
  ${GLIDE_EXTRA:-}

python3 scripts/caption-video.py "$TMP" "$REC.captions.json" artifacts/walkthrough-v3.mp4
ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 artifacts/walkthrough-v3.mp4 | xargs printf "artifacts/walkthrough-v3.mp4: %.1f s\n"
