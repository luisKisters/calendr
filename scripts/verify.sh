#!/bin/bash
# Full verification: build, tests, grep gates, app bundle, snapshots, walkthrough (E2E + video), perf, launch time.
# Must pass before any step is called done.  Usage: scripts/verify.sh [--fast]   (--fast skips walkthrough video + perf)
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
FAST=0; [ "${1:-}" = "--fast" ] && FAST=1
step() { printf '\n\033[1m== %s\033[0m\n' "$1"; }

step "grep gates (animations only through the Motion tokens, no third-party packages)"
# v2 animates, but every curve comes from `Motion` (one curve, four durations, Reduce Motion aware): no raw .easeIn/.linear/.default literals.
if grep -rnE "\.animation\(\s*\.|withAnimation\(\s*\.|NSAnimationContext\.runAnimationGroup|\.transaction \{ *\$0\.animation = nil" Sources | grep -v "^Sources/Calendr/Headless"; then
  echo "raw animation curve found in app sources (use Motion.fast/base/slow/sheet/spring)"; exit 1
fi
if grep -q "\.package(" Package.swift; then echo "Package.swift has dependencies"; exit 1; fi
echo ok

step "swift build"
swift build 2>&1 | tail -3

step "swift test"
swift test 2>&1 | grep -E "Test run|✘|error:" | tail -20
swift test 2>&1 | grep -q "Test run with .* passed" || { echo "tests failed"; exit 1; }

step "build app bundle"
scripts/build-app.sh 2>&1 | tail -2
BIN=build/Calendr.app/Contents/MacOS/Calendr
codesign --verify --deep build/Calendr.app && echo "signature ok"

step "snapshots (every state in design/states.json)"
CONFIG=release scripts/snapshots.sh

if [ $FAST -eq 0 ]; then
  step "walkthrough v2: E2E assertions + artifacts/walkthrough-v2.mp4 (real animations sampled in real time)"
  mkdir -p artifacts
  "$BIN" --walkthrough --record artifacts/walkthrough-v2.mp4 --size 1440x900 | tail -4
  swift scripts/extract-frames.swift artifacts/walkthrough-v2.mp4 artifacts/frames 2 20 40 60 80 100 2>&1 | grep -E "duration|frame at"
  swift scripts/video-info.swift artifacts/walkthrough-v2.mp4 > artifacts/tmp-videoinfo.txt 2>&1 || true
  python3 - <<'PY'
import re, sys
t = open("artifacts/tmp-videoinfo.txt").read()
print(t.strip().splitlines()[0])
d = float(re.search(r"dur ([0-9.]+)", t).group(1))
assert "codec avc1" in t and "playable true" in t and "fps 30.0" in t, "video must be playable H.264 (avc1) at 30 fps"
assert 90 <= d <= 150, f"video duration {d}s outside 90-150s"
print(f"video duration {d:.1f}s ok, avc1 30 fps")
PY
  rm -f artifacts/tmp-videoinfo.txt

  step "performance (week and month navigation p50/p95 with animations off, week with animations on, cold launch)"
  ok=0
  for attempt in 1 2 3; do
    if CALENDR_PERF_STRICT=1 "$BIN" --perf | tee artifacts/perf.txt | tail -9 && [ "${PIPESTATUS[0]}" -eq 0 ]; then ok=1; break; fi
    echo "perf attempt $attempt over budget, retrying"
  done
  [ $ok -eq 1 ] || { echo "performance budget missed"; exit 1; }

  step "real app launch (demo mode)"
  "$BIN" --demo --print-launch

  step "DMG: build, mount, check app + Applications link + codesign, launch from the volume, detach"
  scripts/make-dmg.sh 2>&1 | tail -8
  ls -l dist/Calendr.dmg
fi

step "verify passed"
