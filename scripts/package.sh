#!/bin/bash
# Builds a universal StickySideNote.app and packs it into a drag-to-install disk image.
#   Usage: bash scripts/package.sh [version]     -> .build/StickySideNote-<version>.dmg
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)}"
UNIVERSAL=1 VERSION="$VERSION" bash scripts/build-app.sh

STAGE=".build/dmg"
DMG=".build/StickySideNote-$VERSION.dmg"
rm -rf "${STAGE:?}" "${DMG:?}"
mkdir -p "$STAGE"
cp -R .build/StickySideNote.app "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "StickySideNote" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
echo "$DMG"
