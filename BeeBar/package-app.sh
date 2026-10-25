#!/bin/bash
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
APP_BUNDLE="$DIR/BeeBar.app"

echo "Packaging BeeBar.app..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

if [ -d "$DIR/Resources" ]; then
    cp -R "$DIR/Resources/"* "$APP_BUNDLE/Contents/Resources/"
fi

cp "$DIR/.build/release/BeeBar" "$APP_BUNDLE/Contents/MacOS/BeeBar"
chmod +x "$APP_BUNDLE/Contents/MacOS/BeeBar"

cat <<EOF > "$APP_BUNDLE/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>BeeBar</string>
    <key>CFBundleIdentifier</key>
    <string>computer.bee.beebar</string>
    <key>CFBundleName</key>
    <string>BeeBar</string>
    <key>CFBundleDisplayName</key>
    <string>Bee Menu Bar</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSRequiresAquaSystemAppearance</key>
    <false/>
</dict>
</plist>
EOF

echo "✅ BeeBar.app successfully created at $APP_BUNDLE"
