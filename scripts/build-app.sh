#!/bin/bash
# Builds build/Calendr.app. Set SIGNING_IDENTITY for Developer ID signing.
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

# Google Calendar API (v4 Phase 8b): only when CALENDR_GOOGLE_CLIENT_ID is set (an iOS-type OAuth client ID, never committed).
# It goes into Info.plist with its reversed-client-ID URL scheme, which ASWebAuthenticationSession receives the sign-in redirect on.
GOOGLE_PLIST=""
if [ -n "${CALENDR_GOOGLE_CLIENT_ID:-}" ]; then
  case "$CALENDR_GOOGLE_CLIENT_ID" in *.apps.googleusercontent.com) ;; *) echo "CALENDR_GOOGLE_CLIENT_ID must end in .apps.googleusercontent.com"; exit 1 ;; esac
  GOOGLE_SCHEME="com.googleusercontent.apps.${CALENDR_GOOGLE_CLIENT_ID%.apps.googleusercontent.com}"
  GOOGLE_PLIST="<key>CalendrGoogleClientID</key><string>$CALENDR_GOOGLE_CLIENT_ID</string>
  <key>CFBundleURLTypes</key><array><dict><key>CFBundleURLName</key><string>Google sign-in</string><key>CFBundleURLSchemes</key><array><string>$GOOGLE_SCHEME</string></array></dict></array>"
fi

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
  <key>CFBundleShortVersionString</key><string>1.1.1</string>
  <key>CFBundleVersion</key><string>3</string>
  <key>LSMinimumSystemVersion</key><string>15.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.productivity</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>NSCalendarsFullAccessUsageDescription</key><string>Calendr shows and edits the events in your Google, iCloud and local calendars.</string>
  <key>NSCalendarsUsageDescription</key><string>Calendr shows and edits the events in your Google, iCloud and local calendars.</string>
  $GOOGLE_PLIST
  <key>NSContactsUsageDescription</key><string>Calendr shows the names of guests that events list only by their email address, and suggests people when you add participants.</string>
</dict>
</plist>
PLIST

if [ -n "${SIGNING_IDENTITY:-}" ]; then
  codesign --force --sign "$SIGNING_IDENTITY" --options runtime --timestamp --entitlements scripts/Calendr.entitlements "$APP"
else
  codesign --force --sign - "$APP"
fi
codesign --verify --deep --strict "$APP"
echo "Built $APP"
