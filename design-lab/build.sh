#!/bin/bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# CLT 27 needs an Xcode macro plugin; use the installed compatible SDK.
if [ -z "${SDKROOT:-}" ] && [ -d /Library/Developer/CommandLineTools/SDKs/MacOSX26.sdk ]; then
    export SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.sdk
fi
swift build --package-path "$HERE" -c release --disable-sandbox
BIN=$(swift build --package-path "$HERE" -c release --show-bin-path)
APP="$HERE/../.local/design-lab/OpenConnect Design Lab.app"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN/DesignLab" "$APP/Contents/MacOS/DesignLab"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>OpenConnect Design Lab</string>
<key>CFBundleIdentifier</key><string>ru.ocmac.designlab</string>
<key>CFBundleExecutable</key><string>DesignLab</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1</string>
<key>LSMinimumSystemVersion</key><string>14.4</string>
</dict></plist>
PLIST
codesign --force --sign - "$APP"
echo "$APP"
