#!/bin/bash
# Builds a release binary and assembles .build/StickySideNote.app (ad-hoc signed).
#   UNIVERSAL=1   build for both Apple silicon and Intel
#   VERSION=x.y.z stamp this version into the app (default: the one in Resources/Info.plist)
set -euo pipefail
cd "$(dirname "$0")/.."

ARCHS=()
if [ "${UNIVERSAL:-0}" = "1" ]; then ARCHS=(--arch arm64 --arch x86_64); fi

swift build -c release ${ARCHS[@]+"${ARCHS[@]}"}
BIN="$(swift build -c release ${ARCHS[@]+"${ARCHS[@]}"} --show-bin-path)/StickySideNote"

APP=".build/StickySideNote.app"
rm -rf "${APP:?}"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/StickySideNote"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/Fonts/*.ttf "$APP/Contents/Resources/"
cp Resources/AppIcon.icns "$APP/Contents/Resources/"
if [ -n "${VERSION:-}" ]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
fi
codesign --force --sign - "$APP"
echo "Built $APP ($(lipo -archs "$APP/Contents/MacOS/StickySideNote"))"
