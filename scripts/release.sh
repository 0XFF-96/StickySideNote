#!/bin/bash
# Publishes a release: tests, builds the disk image, creates the GitHub release and
# points the Homebrew cask at it.
#   Usage: bash scripts/release.sh 0.1.0
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:?usage: release.sh <version>, e.g. 0.1.0}"
REPO="0XFF-96/StickySideNote"
TAP="0XFF-96/homebrew-tap"

[ -z "$(git status --porcelain)" ] || { echo "Commit or stash your changes first." >&2; exit 1; }
[ "$(git branch --show-current)" = "main" ] || { echo "Release from main." >&2; exit 1; }

swift test
DMG="$(bash scripts/package.sh "$VERSION" | tail -1)"
SHA="$(shasum -a 256 "$DMG" | awk '{print $1}')"

# Keep the version in the source tree in step with the release.
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" Resources/Info.plist
if [ -n "$(git status --porcelain)" ]; then
    git commit -qam "chore: version $VERSION"
fi
git tag "v$VERSION"
git push -q origin main "v$VERSION"

gh release create "v$VERSION" "$DMG#StickySideNote-$VERSION.dmg" --repo "$REPO" \
    --title "StickySideNote $VERSION" --generate-notes

# Update the cask in the tap.
WORK=".build/homebrew-tap"
rm -rf "${WORK:?}"
gh repo clone "$TAP" "$WORK" -- -q
mkdir -p "$WORK/Casks"
cat > "$WORK/Casks/stickysidenote.rb" <<CASK
cask "stickysidenote" do
  version "$VERSION"
  sha256 "$SHA"

  url "https://github.com/$REPO/releases/download/v#{version}/StickySideNote-#{version}.dmg"
  name "StickySideNote"
  desc "Sticky notes that stay on the edge of the screen"
  homepage "https://github.com/$REPO"

  depends_on macos: ">= :sonoma"

  app "StickySideNote.app"

  # The app is not notarised, so macOS would refuse to open a quarantined copy.
  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-dr", "com.apple.quarantine", "#{appdir}/StickySideNote.app"]
  end

  uninstall quit: "com.jimmyli.StickySideNote"

  zap trash: "~/Library/Application Support/StickySideNote"
end
CASK
git -C "$WORK" add Casks/stickysidenote.rb
git -C "$WORK" commit -qm "stickysidenote $VERSION"
git -C "$WORK" push -q
echo "Released v$VERSION: https://github.com/$REPO/releases/tag/v$VERSION"
