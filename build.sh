#!/bin/bash
# Builds build/Gitizen.app, a menu bar-only (no Dock icon) app bundle.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

APP=build/Gitizen.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/Gitizen "$APP/Contents/MacOS/Gitizen"

cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>Gitizen</string>
    <key>CFBundleIdentifier</key><string>io.github.smilindave26.gitizen</string>
    <key>CFBundleName</key><string>Gitizen</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>15.0</string>
    <key>LSUIElement</key><true/>
</dict>
</plist>
EOF

codesign --force --sign - "$APP"
echo "Built $APP"
