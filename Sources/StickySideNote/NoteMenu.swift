import AppKit
import SwiftUI
import StickyCore

/// The secondary-click menu on a note: a row of colour dots, then delete.
@MainActor
enum NoteMenu {
    static func show(for note: Note, model: RailModel, in view: NSView, with event: NSEvent) {
        let menu = NSMenu()
        menu.autoenablesItems = false

        let dots = NSMenuItem()
        let host = NSHostingView(rootView: ColorDots(current: note.color) { color in
            model.setColor(note.id, color)
            menu.cancelTracking()
        })
        host.frame = NSRect(origin: .zero, size: host.fittingSize)
        dots.view = host
        menu.addItem(dots)
        menu.addItem(.separator())

        let delete = ClosureMenuItem(title: L10n.deleteNote) { model.delete(note.id) }
        menu.addItem(delete)

        NSMenu.popUpContextMenu(menu, with: event, for: view)
    }
}

private struct ColorDots: View {
    let current: NoteColor
    let pick: (NoteColor) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(NoteColor.allCases, id: \.self) { color in
                Circle()
                    .fill(Theme.color(color))
                    .frame(width: 18, height: 18)
                    .overlay {
                        if color == current {
                            Circle().stroke(Theme.brand, lineWidth: 2).padding(-3)
                        }
                    }
                    .contentShape(Circle())
                    .onTapGesture { pick(color) }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}

/// A menu item that runs a closure, so callers need no target object.
final class ClosureMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(title: String, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(run), keyEquivalent: "")
        target = self
    }

    required init(coder: NSCoder) { fatalError("not used") }

    @objc private func run() { handler() }
}
