#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
VERSION="1.2"
BUILD="3"

swift build -c release

APP="$ROOT/Feathr Desk.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$ROOT/.build/release/FeathrDesk" "$APP/Contents/MacOS/Feathr Desk"

ICONSET="$ROOT/.build/AppIcon.iconset"
ICNS="$ROOT/.build/AppIcon.icns"
if [[ ! -f "$ICNS" || "$ROOT/scripts/make-icon.swift" -nt "$ICNS" ]]; then
  rm -rf "$ICONSET"
  swift "$ROOT/scripts/make-icon.swift" "$ICONSET"
  iconutil -c icns "$ICONSET" -o "$ICNS"
fi
cp "$ICNS" "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>Feathr Desk</string>
  <key>CFBundleIdentifier</key>
  <string>com.mfccc.feathrdesk</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>Feathr Desk</string>
  <key>CFBundleDisplayName</key>
  <string>Feathr Desk</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${VERSION}</string>
  <key>CFBundleVersion</key>
  <string>${BUILD}</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.business</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSSupportsAutomaticGraphicsSwitching</key>
  <true/>
  <key>NSHumanReadableCopyright</key>
  <string>© 2026 Mid-Fairfield Child Guidance Center, Inc. Internal operator tool.</string>
</dict>
</plist>
EOF

plutil -lint "$APP/Contents/Info.plist" > /dev/null
codesign --force --sign - "$APP" > /dev/null 2>&1 || echo "Note: ad-hoc signing skipped"
touch "$APP"
echo "Built $APP (Feathr Desk ${VERSION}, build ${BUILD})"
