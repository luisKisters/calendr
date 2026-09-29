#!/bin/bash
# Builds build/Calendr.app (release, ad-hoc signed).
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

swift build -c release
BIN="$(swift build -c release --show-bin-path)/Calendr"

APP=build/Calendr.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Calendr"
scripts/make-icon.sh   # no-op when design/icon/AppIcon.icns exists
cp design/icon/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
# Optional menu bar template glyph
[ -f design/icon/MenuBarTemplate.png ] && cp design/icon/MenuBarTemplate.png "$APP/Contents/Resources/MenuBarTemplate.png"
[ -f design/icon/MenuBarTemplate@2x.png ] && cp design/icon/MenuBarTemplate@2x.png "$APP/Contents/Resources/MenuBarTemplate@2x.png"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Calendr</string>
  <key>CFBundleDisplayName</key><string>Calendr</string>
  <key>CFBundleIdentifier</key><string>com.luiskisters.calendr</string>
  <key>CFBundleExecutable</key><string>Calendr</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>15.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.productivity</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>NSCalendarsFullAccessUsageDescription</key><string>Calendr shows and edits the events in your Google, iCloud and local calendars.</string>
  <key>NSCalendarsUsageDescription</key><string>Calendr shows and edits the events in your Google, iCloud and local calendars.</string>
</dict>
</plist>
PLIST

codesign --force --deep -s - "$APP"
echo "Built $APP"
