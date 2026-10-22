#!/bin/bash
# Compiles src/main.swift into an app bundle, ~/Applications/KeepMacAwake.app by default.
# Usage: scripts/build.sh [app-path]   ARCHS="arm64 x86_64" builds a universal binary; VERSION sets the bundle version.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="${1:-$HOME/Applications/KeepMacAwake.app}"
ARCHS="${ARCHS:-$(uname -m)}"
VERSION="${VERSION:-1.0}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# Regenerate the icon only when it is missing; make-icon.swift is the source of truth.
if [ ! -f "$ROOT/src/AppIcon.icns" ]; then
	swiftc -O "$ROOT/src/make-icon.swift" -o "$WORK/make-icon"
	"$WORK/make-icon" "$WORK/AppIcon.iconset"
	iconutil -c icns "$WORK/AppIcon.iconset" -o "$ROOT/src/AppIcon.icns"
fi
cp "$ROOT/src/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
# Bundled so a downloaded app can grant its own permission without a clone.
cp "$ROOT/scripts/install-sudoers.sh" "$APP/Contents/Resources/install-sudoers.sh"

slices=()
for arch in $ARCHS; do
	swiftc -O -target "$arch-apple-macosx14.0" "$ROOT/src/main.swift" -o "$WORK/KeepMacAwake-$arch"
	slices+=("$WORK/KeepMacAwake-$arch")
done
lipo -create "${slices[@]}" -output "$APP/Contents/MacOS/KeepMacAwake"

cat > "$APP/Contents/Info.plist" <<PLIST
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
	<string>$VERSION</string>
	<key>CFBundleVersion</key>
	<string>$VERSION</string>
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
