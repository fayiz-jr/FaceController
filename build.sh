#!/bin/zsh
# Builds FaceController.app. With --install, puts it in /Applications and opens it.
set -euo pipefail
cd "$(dirname "$0")"

APP=build/FaceController.app
swift build -c release

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/FaceController "$APP/Contents/MacOS/FaceController"

# App icon: 🎭 on a rounded gradient tile, drawn once and cached.
if [[ ! -f build/AppIcon.icns ]]; then
    swift Tools/make-icon.swift build/AppIcon.iconset
    iconutil -c icns build/AppIcon.iconset -o build/AppIcon.icns
fi
cp build/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key><string>com.fayizjr.FaceController</string>
    <key>CFBundleName</key><string>FaceController</string>
    <key>CFBundleDisplayName</key><string>FaceController</string>
    <key>CFBundleExecutable</key><string>FaceController</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSLocalNetworkUsageDescription</key>
    <string>FaceController receives face tracking from the Live Link Face app on your iPhone.</string>
</dict>
</plist>
PLIST

# A stable signing identity keeps the Accessibility permission across rebuilds.
IDENTITY=$(security find-identity -v -p codesigning | awk -F'"' '/Apple Development/ {print $2; exit}')
codesign --force --options runtime --sign "${IDENTITY:--}" "$APP"
echo "✓ Built $APP (signed: ${IDENTITY:-ad hoc})"

if [[ "${1:-}" == "--install" ]]; then
    pkill -x FaceController 2>/dev/null || true
    sleep 0.5
    rm -rf /Applications/FaceController.app
    ditto "$APP" /Applications/FaceController.app
    open /Applications/FaceController.app
    echo "✓ Installed /Applications/FaceController.app"
fi
