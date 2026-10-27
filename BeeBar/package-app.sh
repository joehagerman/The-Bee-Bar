#!/bin/bash
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
APP_BUNDLE="$DIR/BeeBar.app"
STAGE_DIR="$(mktemp -d /tmp/beebar_build.XXXXXX)"
STAGE_APP="$STAGE_DIR/BeeBar.app"

echo "Packaging BeeBar.app in clean staging directory..."
mkdir -p "$STAGE_APP/Contents/MacOS"
mkdir -p "$STAGE_APP/Contents/Resources"

if [ -d "$DIR/Resources" ]; then
    cp -R "$DIR/Resources/"* "$STAGE_APP/Contents/Resources/"
fi

cp "$DIR/.build/release/BeeBar" "$STAGE_APP/Contents/MacOS/BeeBar"
chmod +x "$STAGE_APP/Contents/MacOS/BeeBar"

cat <<EOF > "$STAGE_APP/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>BeeBar</string>
    <key>CFBundleIdentifier</key>
    <string>computer.bee.beebar</string>
    <key>CFBundleName</key>
    <string>The Bee Bar</string>
    <key>CFBundleDisplayName</key>
    <string>The Bee Bar</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.1.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSSupportsAutomaticTermination</key>
    <false/>
    <key>NSSupportsSuddenTermination</key>
    <false/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSRequiresAquaSystemAppearance</key>
    <false/>
</dict>
</plist>
EOF

echo "Cleaning extended attributes and signing bundle..."
xattr -c "$STAGE_APP" 2>/dev/null || true
xattr -rc "$STAGE_APP" 2>/dev/null || true

codesign --force --deep --sign - "$STAGE_APP"
codesign -vvv --deep --strict "$STAGE_APP"

rm -rf "$APP_BUNDLE"
cp -R "$STAGE_APP" "$APP_BUNDLE"
rm -rf "$STAGE_DIR"

echo "BeeBar.app successfully created, signed, and verified at $APP_BUNDLE"
