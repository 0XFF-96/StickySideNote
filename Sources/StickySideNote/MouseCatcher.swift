import SwiftUI
import AppKit

/// An invisible AppKit view laid over a SwiftUI view to receive mouse events.
///
/// The rail lives in a panel that never becomes key for hovering or clicking, and
/// SwiftUI's own hover and tap handling is unreliable there. Tracking areas with
/// `.activeAlways` and plain `mouseUp` work regardless of key state.
struct MouseCatcher: NSViewRepresentable {
    var passThrough = false
    /// When set, dragging from this view moves the whole rail instead of clicking.
    var drag: RailDrag?
    var onHover: (Bool) -> Void = { _ in }
    var onPress: (Bool) -> Void = { _ in }
    var onClick: () -> Void = {}
    var onDoubleClick: () -> Void = {}
    var onSecondaryClick: (NSView, NSEvent) -> Void = { _, _ in }

    func makeNSView(context: Context) -> CatcherView { CatcherView() }

    func updateNSView(_ view: CatcherView, context: Context) {
        view.handlers = self
    }

    static func dismantleNSView(_ view: CatcherView, coordinator: ()) {
        // A removed view never gets mouseExited; report it so hover state cannot stick.
        view.handlers?.onHover(false)
    }
}

final class CatcherView: NSView {
    var handlers: MouseCatcher?
    private var tracking: NSTrackingArea?
    private var downAt: NSPoint?
    private var isDragging = false

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(rect: .zero,
                                  options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                  owner: self)
        addTrackingArea(area)
        tracking = area
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        handlers?.passThrough == true ? nil : super.hitTest(point)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseEntered(with event: NSEvent) { handlers?.onHover(true) }
    override func mouseExited(with event: NSEvent) { handlers?.onHover(false) }

    override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.control) {
            handlers?.onSecondaryClick(self, event)
        } else {
            downAt = NSEvent.mouseLocation
            handlers?.onPress(true)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let drag = handlers?.drag, let downAt else { return }
        let now = NSEvent.mouseLocation
        if !isDragging {
            // A few points of slack so an unsteady click still counts as a click.
            guard hypot(now.x - downAt.x, now.y - downAt.y) > 4 else { return }
            isDragging = true
            handlers?.onPress(false)
            drag.onBegan(downAt)
        }
        drag.onMoved(now)
    }

    override func mouseUp(with event: NSEvent) {
        downAt = nil
        if isDragging {
            isDragging = false
            handlers?.drag?.onEnded(NSEvent.mouseLocation)
            return
        }
        handlers?.onPress(false)
        guard !event.modifierFlags.contains(.control),
              bounds.contains(convert(event.locationInWindow, from: nil)) else { return }
        if event.clickCount >= 2 {
            handlers?.onDoubleClick()
        } else {
            handlers?.onClick()
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        handlers?.onSecondaryClick(self, event)
    }

    /// This view covers the note, so hand scrolling to the scroll view underneath (long notes).
    override func scrollWheel(with event: NSEvent) {
        guard let root = window?.contentView else { return }
        Self.scrollView(in: root, under: event.locationInWindow)?.scrollWheel(with: event)
    }

    /// Deepest scroll view whose bounds contain the window point.
    private static func scrollView(in view: NSView, under windowPoint: NSPoint) -> NSScrollView? {
        for sub in view.subviews.reversed() {
            if let found = scrollView(in: sub, under: windowPoint) { return found }
        }
        guard let scroll = view as? NSScrollView,
              scroll.bounds.contains(scroll.convert(windowPoint, from: nil)) else { return nil }
        return scroll
    }

    /// Whether the pointer is over this view right now (tracking loops can swallow mouseExited).
    var containsPointer: Bool {
        guard let window else { return false }
        return bounds.contains(convert(window.mouseLocationOutsideOfEventStream, from: nil))
    }
}
