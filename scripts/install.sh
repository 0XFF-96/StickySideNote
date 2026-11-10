#!/bin/bash
# Builds StickySideNote from source and installs it to /Applications.
set -euo pipefail
cd "$(dirname "$0")/.."

bash scripts/build-app.sh

pkill -x StickySideNote || true
rm -rf /Applications/StickySideNote.app
cp -R .build/StickySideNote.app /Applications/StickySideNote.app
open /Applications/StickySideNote.app
echo "Installed /Applications/StickySideNote.app"
