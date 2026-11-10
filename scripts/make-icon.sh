#!/bin/bash
# Redraws the icon and packs it into Resources/AppIcon.icns.
set -euo pipefail
cd "$(dirname "$0")/.."

swift scripts/make-icon.swift Resources/AppIcon.png

SET=".build/AppIcon.iconset"
mkdir -p "$SET"
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" Resources/AppIcon.png --out "$SET/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z "$double" "$double" Resources/AppIcon.png --out "$SET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$SET" -o Resources/AppIcon.icns
echo "wrote Resources/AppIcon.icns"
