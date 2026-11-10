#!/bin/bash
# Builds StickySideNote, assembles the .app and installs it to /Applications.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
BIN="$(swift build -c release --show-bin-path)/StickySideNote"

APP=".build/StickySideNote.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/StickySideNote"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/Fonts/*.ttf "$APP/Contents/Resources/"
cp Resources/AppIcon.icns "$APP/Contents/Resources/"
codesign --force --sign - "$APP"

pkill -x StickySideNote || true
rm -rf /Applications/StickySideNote.app
cp -R "$APP" /Applications/StickySideNote.app
open /Applications/StickySideNote.app
echo "Installed /Applications/StickySideNote.app"
