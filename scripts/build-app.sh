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
# Instrument Sans (SIL OFL) and its license; Typeface.swift looks in Contents/Resources/Fonts first
mkdir -p "$APP/Contents/Resources/Fonts"
cp Sources/Calendr/Resources/Fonts/InstrumentSans.ttf Sources/Calendr/Resources/Fonts/OFL.txt "$APP/Contents/Resources/Fonts/"

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
  <key>CFBundleShortVersionString</key><string>1.1.0</string>
  <key>CFBundleVersion</key><string>2</string>
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
