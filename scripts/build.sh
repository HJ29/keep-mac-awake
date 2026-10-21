#!/bin/bash
# Compiles src/main.swift into ~/Applications/KeepMacAwake.app
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$HOME/Applications/KeepMacAwake.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# Regenerate the icon only when it is missing; make-icon.swift is the source of truth.
if [ ! -f "$ROOT/src/AppIcon.icns" ]; then
	WORK="$(mktemp -d)"
	swiftc -O "$ROOT/src/make-icon.swift" -o "$WORK/make-icon"
	"$WORK/make-icon" "$WORK/AppIcon.iconset"
	iconutil -c icns "$WORK/AppIcon.iconset" -o "$ROOT/src/AppIcon.icns"
	rm -rf "$WORK"
fi
cp "$ROOT/src/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

swiftc -O -target "$(uname -m)-apple-macosx14.0" "$ROOT/src/main.swift" -o "$APP/Contents/MacOS/KeepMacAwake"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleName</key>
	<string>Keep Mac Awake</string>
	<key>CFBundleDisplayName</key>
	<string>Keep Mac Awake</string>
	<key>CFBundleExecutable</key>
	<string>KeepMacAwake</string>
	<key>CFBundleIconFile</key>
	<string>AppIcon</string>
	<key>CFBundleIdentifier</key>
	<string>io.github.hj29.keep-mac-awake</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>LSMinimumSystemVersion</key>
	<string>14.0</string>
	<key>LSUIElement</key>
	<true/>
	<key>NSHighResolutionCapable</key>
	<true/>
</dict>
</plist>
PLIST

# Ad-hoc signature keeps the bundle identity stable across rebuilds (Login Items, TCC).
codesign --force --sign - "$APP"

echo "Built $APP"
