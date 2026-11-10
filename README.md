# StickySideNote

Sticky notes that stay on the left edge of your Mac's screen.

- **Hover** a tab to read the whole note.
- **Click** to copy it to the clipboard.
- **Double-click** to edit; press Esc or click elsewhere to save. Saving an empty note deletes it.
- **Right-click** to change colour or delete. The **+** tab adds a note.

- **Drag** any tab to move the whole rail; it snaps to the nearer side of the screen you drop it on.

The menu bar icon can add a note (blank or from the clipboard), move the rail to a side of any
screen ("移动到"), hide or show all notes, toggle launch at login, and quit.
Notes hide while another app is in full screen.

## Install

    bash scripts/install.sh

Builds a release binary, assembles `StickySideNote.app`, installs it to `/Applications` and starts it.
Requires Xcode (Swift 6 toolchain) and macOS 14 or later.

## Uninstall

1. Turn off "开机自动启动" in the menu bar menu, then choose "退出".
2. Delete `/Applications/StickySideNote.app`.
3. Delete `~/Library/Application Support/StickySideNote/` (your notes).

## Development

    bash scripts/make-icon.sh       # redraw the icon and rebuild Resources/AppIcon.icns

    swift test                      # unit tests for StickyCore
    STICKY_SNAPSHOT_DIR=/tmp/snap /Applications/StickySideNote.app/Contents/MacOS/StickySideNote

The second command renders the rail in each state to PNG files in that directory, using a
separate `notes.json` there, and quits. It is a way to check the look without screen recording.

Design: `docs/superpowers/specs/2026-11-10-sticky-side-note-design.md`.
