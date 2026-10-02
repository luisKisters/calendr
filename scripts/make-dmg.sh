#!/bin/bash
# Builds dist/Calendr.dmg (app + Applications symlink) and verifies it.
# Set SIGNING_IDENTITY and NOTARY_PROFILE for a signed, notarized release.
# Usage: scripts/make-dmg.sh [--no-verify]
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

if [ -n "${NOTARY_PROFILE:-}" ] && [ -z "${SIGNING_IDENTITY:-}" ]; then
  echo "FAIL: NOTARY_PROFILE requires SIGNING_IDENTITY" >&2
  exit 1
fi
scripts/build-app.sh

mkdir -p dist
if [ -n "${NOTARY_PROFILE:-}" ]; then
  ZIP=dist/Calendr-notarization.zip
  rm -f "$ZIP"
  ditto -c -k --keepParent build/Calendr.app "$ZIP"
  xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait --output-format json > dist/app-notarization.json
  python3 -c 'import json; d=json.load(open("dist/app-notarization.json")); print(d); assert d["status"] == "Accepted", "App notarization failed"'
  xcrun stapler staple build/Calendr.app
  xcrun stapler validate build/Calendr.app
  spctl --assess --type execute --verbose=2 build/Calendr.app
  rm -f "$ZIP"
fi

STAGE=dist/staging
DMG=dist/Calendr.dmg
rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
cp -R build/Calendr.app "$STAGE/Calendr.app"
ln -s /Applications "$STAGE/Applications"

hdiutil create -volname Calendr -srcfolder "$STAGE" -format UDZO -ov "$DMG"
if [ -n "${SIGNING_IDENTITY:-}" ]; then
  codesign --force --sign "$SIGNING_IDENTITY" --timestamp "$DMG"
fi
if [ -n "${NOTARY_PROFILE:-}" ]; then
  xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait --output-format json > dist/dmg-notarization.json
  python3 -c 'import json; d=json.load(open("dist/dmg-notarization.json")); print(d); assert d["status"] == "Accepted", "DMG notarization failed"'
  xcrun stapler staple "$DMG"
  xcrun stapler validate "$DMG"
  spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG"
fi
echo "Created $DMG ($(du -h "$DMG" | cut -f1))"

[ "${1:-}" = "--no-verify" ] && exit 0

# ---- Verify the DMG ----
MNT="$(mktemp -d)"
ATTACHED=0
cleanup() {
  if [ "$ATTACHED" = 1 ]; then hdiutil detach "$MNT" -force >/dev/null 2>&1 || true; fi
  rmdir "$MNT" 2>/dev/null || true
}
trap cleanup EXIT

hdiutil attach -nobrowse -readonly -mountpoint "$MNT" "$DMG" >/dev/null
ATTACHED=1

[ -d "$MNT/Calendr.app" ] || { echo "FAIL: Calendr.app missing in DMG"; exit 1; }
[ -L "$MNT/Applications" ] || { echo "FAIL: Applications symlink missing"; exit 1; }
echo "ok: Calendr.app and Applications symlink present"

codesign --verify --deep --strict "$MNT/Calendr.app"
echo "ok: codesign --verify --deep --strict passed"

# Launch the mounted binary; it prints a line and exits by itself.
OUTFILE="$(mktemp)"
"$MNT/Calendr.app/Contents/MacOS/Calendr" --demo --print-launch >"$OUTFILE" 2>&1 &
PID=$!
for _ in $(seq 1 30); do
  kill -0 "$PID" 2>/dev/null || break
  sleep 1
done
if kill -0 "$PID" 2>/dev/null; then
  kill "$PID" 2>/dev/null || true
  echo "FAIL: launch did not exit within 30s"; cat "$OUTFILE"; rm -f "$OUTFILE"; exit 1
fi
wait "$PID" || { echo "FAIL: launch exited non-zero"; cat "$OUTFILE"; rm -f "$OUTFILE"; exit 1; }
echo "ok: launch output: $(head -n 3 "$OUTFILE")"
rm -f "$OUTFILE"

hdiutil detach "$MNT" >/dev/null
ATTACHED=0
echo "DMG verified: $DMG ($(du -h "$DMG" | cut -f1))"
