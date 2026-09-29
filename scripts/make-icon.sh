#!/bin/bash
# Regenerates design/icon/AppIcon.icns (+ MenuBarTemplate PNGs) from the SVG masters.
# Skips if AppIcon.icns exists unless --force is given.
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

OUT=design/icon/AppIcon.icns
if [ -f "$OUT" ] && [ "${1:-}" != "--force" ]; then
  echo "$OUT exists (use --force to regenerate)"; exit 0
fi

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
render() { # svg size out  (renderer emits a retina-scaled PNG, so normalise with sips)
  swift scripts/render-svg.swift "$1" "$TMP/raw.png" "$2"
  sips -z "$2" "$2" "$TMP/raw.png" --out "$3" >/dev/null
}

render design/icon/icon.svg 1024 "$TMP/master.png"
SET="$TMP/AppIcon.iconset"; mkdir "$SET"
for s in 16 32 128 256 512; do
  sips -z $s $s "$TMP/master.png" --out "$SET/icon_${s}x${s}.png" >/dev/null
  d=$((s * 2))
  sips -z $d $d "$TMP/master.png" --out "$SET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$SET" -o "$OUT"
echo "Wrote $OUT"

# Menu bar template glyph (black on transparent, 18pt @1x/@2x)
render design/icon/menubar.svg 1024 "$TMP/mb.png"
sips -z 18 18 "$TMP/mb.png" --out design/icon/MenuBarTemplate.png >/dev/null
sips -z 36 36 "$TMP/mb.png" --out design/icon/MenuBarTemplate@2x.png >/dev/null
echo "Wrote design/icon/MenuBarTemplate{,@2x}.png"
