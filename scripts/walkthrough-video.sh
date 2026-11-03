#!/bin/bash
# The polished walkthrough of the end-to-end tour (the v4 demo week): the app records itself (2x, 60 fps, no overlays) with cursor
# telemetry and captions, Glide renders it (backdrop, rounded window, cursor, no zoom: the whole window stays in frame),
# scripts/caption-video.py burns the caption chips.
# Usage: scripts/walkthrough-video.sh [--skip-build]     Output: artifacts/walkthrough.mp4
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH="$HOME/.local/bin:$PATH"
command -v glide >/dev/null || { echo "glide not found (https://glide.dipxsy.app)"; exit 1; }
REC=artifacts/walkthrough.mov
TMP=artifacts/tmp/walkthrough.glide.mp4
mkdir -p artifacts/tmp

[ "${1:-}" = "--skip-build" ] || scripts/build-app.sh 2>&1 | tail -2
build/Calendr.app/Contents/MacOS/Calendr --walkthrough --record "$REC" | tail -4
rm -f artifacts/walkthrough.mov.sb-*

glide render "$REC" -o "$TMP" --zoom off \
  --background gradient:#17161d,#0b0b0e,155 --padding 10 --radius 16 --shadow 0.6 \
  --resolution 1080p --quality high \
  --fps 60 --cursor-motion fast --cursor-size 3 --click-effect on \
  ${GLIDE_EXTRA:-}

python3 scripts/caption-video.py "$TMP" "$REC.captions.json" artifacts/walkthrough.mp4
ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 artifacts/walkthrough.mp4 | xargs printf "artifacts/walkthrough.mp4: %.1f s\n"
