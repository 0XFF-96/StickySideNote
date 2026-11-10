import AppKit
import SwiftUI
import Combine
import StickyCore

/// Borderless floating panel that can take keyboard focus (for editing) without activating the app.
final class RailPanel: NSPanel {
    /// Only an edit may take the keyboard; hovering and clicking never do.
    var allowsKey = false
    override var canBecomeKey: Bool { allowsKey }
    override var canBecomeMain: Bool { false }
}

private final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// Owns the panel: keeps it on the left edge and only as large as what is showing,
/// so everything outside the tabs stays clickable.
@MainActor
final class PanelController: NSObject, NSWindowDelegate {
    private let model: RailModel
    private let metrics = ScreenMetrics()
    let panel: RailPanel
    private var sinks: Set<AnyCancellable> = []
    private var keyMonitor: Any?
    private var shrinkWork: DispatchWorkItem?
    private var wasEditing = false
    private var previousApp: NSRunningApplication?
    let hover: HoverRouter
    let drag = RailDrag()
    /// Off in snapshot runs so they never change the real saved placement.
    var persistsPlacement = true
    private var isDragging = false
    private var dragOffset = CGSize.zero
    /// Display the rail lives on; nil means the main display. Kept even while that display
    /// is unplugged, so the rail returns to it when it comes back.
    private var screenNumber: UInt32?

    private static let sideKey = "railSide", screenKey = "railScreen"

    /// Height the rail may use on its current screen.
    var availableHeight: CGFloat { metrics.available }

    /// Room to the right of an expanded card for its shadow and focus ring.
    private static let expandedMargin: CGFloat = 24
    private static let collapsedMargin: CGFloat = 4

    init(model: RailModel) {
        self.model = model
        panel = RailPanel(contentRect: NSRect(x: 0, y: 0, width: 40, height: 100),
                          styleMask: [.borderless, .nonactivatingPanel],
                          backing: .buffered, defer: false)
        hover = HoverRouter(model: model)
        super.init()

        panel.level = .floating
        // No .fullScreenAuxiliary: the rail stays out of other apps' full-screen spaces.
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.isMovable = false
        panel.delegate = self
        let defaults = UserDefaults.standard
        metrics.side = defaults.string(forKey: Self.sideKey).flatMap(RailSide.init(rawValue:)) ?? .left
        screenNumber = (defaults.object(forKey: Self.screenKey) as? NSNumber)?.uint32Value

        let host = FirstMouseHostingView(
            rootView: RailView(model: model, metrics: metrics, hover: hover, drag: drag))
        // The controller sizes the panel; SwiftUI must not push its own size onto the window.
        host.sizingOptions = []
        panel.contentView = host

        drag.onBegan = { [weak self] in self?.beginDrag(at: $0) }
        drag.onMoved = { [weak self] in self?.moveDrag(to: $0) }
        drag.onEnded = { [weak self] in self?.endDrag(at: $0) }


        // objectWillChange fires before the change lands, so read the model on the next turn.
        model.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.sync() }
            .store(in: &sinks)
        let center = NotificationCenter.default
        center.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in self?.reposition() }
            .store(in: &sinks)
        NSWorkspace.shared.notificationCenter
            .publisher(for: NSWorkspace.activeSpaceDidChangeNotification)
            .sink { [weak self] _ in self?.reposition() }
            .store(in: &sinks)

        // Esc ends editing. A text view would otherwise swallow it for completion.
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.model.editingID != nil else { return event }
            if event.keyCode == 53 {
                // Mid-composition (e.g. pinyin) Esc belongs to the input method: it cancels the candidates.
                if self.editorTextView()?.hasMarkedText() == true { return event }
                self.model.commitEdit()
                return nil
            }
            // Editing shortcuts, sent straight to the editor so they work even though the
            // app is not the active one and shows no Edit menu.
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard flags == .command || flags == [.command, .shift],
                  let key = event.charactersIgnoringModifiers?.lowercased(),
                  let text = self.editorTextView() else { return event }
            switch (key, flags == .command) {
            case ("v", true): text.pasteAsPlainText(nil)
            case ("c", true): text.copy(nil)
            case ("x", true): text.cut(nil)
            case ("a", true): text.selectAll(nil)
            case ("z", true): text.undoManager?.undo()
            case ("z", false): text.undoManager?.redo()
            default: return event
            }
            return nil
        }
    }

    func show() {
        reposition()
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }

    /// Recomputes the usable height and the panel frame for the current screen.
    func reposition(animated: Bool = false) {
        guard let screen = currentScreen() else { return }
        let visible = screen.visibleFrame
        let available = visible.height * (1 - RailLayout.topFraction) - RailLayout.bottomMargin
        if metrics.available != available { metrics.available = available }
        if metrics.screenHeight != visible.height { metrics.screenHeight = visible.height }
        applyFrame(expanded: model.isExpanded, animated: animated)
    }

    private func sync() {
        let editing = model.editingID != nil
        if !editing && wasEditing {
            endKeyboardFocus()
        }
        if model.isHidden {
            wasEditing = editing
            hide()
            return
        }
        if !panel.isVisible { panel.orderFrontRegardless() }
        if editing && !wasEditing {
            beginKeyboardFocus()
        }
        wasEditing = editing

        shrinkWork?.cancel()
        if model.isExpanded {
            applyFrame(expanded: true)
        } else {
            // Let the collapse animation finish before the panel stops covering the card.
            let work = DispatchWorkItem { [weak self] in
                guard let self, !self.model.isExpanded else { return }
                self.applyFrame(expanded: false)
            }
            shrinkWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + Theme.duration + 0.06, execute: work)
        }
    }

    /// Editing needs key status. A non-activating panel normally gets it without bringing
    /// the app forward; if the system refuses, activate the app and hand focus back afterwards.
    private func beginKeyboardFocus() {
        previousApp = nil
        panel.allowsKey = true
        panel.makeKey()
        focusEditor()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self, self.model.editingID != nil else { return }
            if !self.panel.isKeyWindow {
                self.previousApp = NSWorkspace.shared.frontmostApplication
                NSApp.activate(ignoringOtherApps: true)
                self.panel.makeKeyAndOrderFront(nil)
            }
            self.focusEditor()
        }
    }

    private func endKeyboardFocus() {
        panel.allowsKey = false
        // Only give focus back if we still hold it: if the user clicked another app to
        // finish editing, that app is already where they want to be.
        if let previousApp, NSApp.isActive {
            previousApp.activate()
        } else if panel.isKeyWindow {
            // A key panel keeps the keyboard until another window takes it. Taking the
            // panel off screen and back hands key status to the front app's window.
            panel.orderOut(nil)
            if !model.isHidden { panel.orderFrontRegardless() }
        }
        previousApp = nil
    }

    /// The text view behind the SwiftUI editor, if an edit is showing.
    private func editorTextView() -> NSTextView? {
        func find(_ view: NSView) -> NSTextView? {
            if let text = view as? NSTextView, text.isEditable { return text }
            for sub in view.subviews { if let found = find(sub) { return found } }
            return nil
        }
        return panel.contentView.flatMap(find)
    }

    /// SwiftUI's focus request can be dropped when it arrives before the panel is key,
    /// so put the caret in the editor directly.
    private func focusEditor() {
        guard let text = editorTextView(), panel.firstResponder !== text else { return }
        panel.makeFirstResponder(text)
        text.setSelectedRange(NSRange(location: text.string.utf16.count, length: 0))
    }

    // MARK: Placement

    private static func number(of screen: NSScreen) -> UInt32? {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }

    private func currentScreen() -> NSScreen? {
        if let screenNumber, let match = NSScreen.screens.first(where: { Self.number(of: $0) == screenNumber }) {
            return match
        }
        return NSScreen.screens.first
    }

    /// Shows the rail on a side without saving the choice (snapshot runs).
    func preview(side: RailSide) {
        metrics.side = side
        reposition()
    }

    // MARK: Dragging to another edge or screen

    private func beginDrag(at point: NSPoint) {
        guard model.editingID == nil else { return }
        isDragging = true
        hover.isEnabled = false
        model.setHover(nil)
        shrinkWork?.cancel()
        // Drag the collapsed rail, not a 290 pt wide panel.
        let layout = RailLayout.compute(noteCount: model.store.notes.count, available: metrics.available)
        let size = collapsedSize(layout)
        let x = metrics.side == .left ? panel.frame.minX : panel.frame.maxX - size.width
        panel.setFrame(NSRect(x: x, y: panel.frame.maxY - size.height, width: size.width, height: size.height),
                       display: true)
        dragOffset = CGSize(width: point.x - panel.frame.minX, height: point.y - panel.frame.minY)
        NSCursor.closedHand.push()
    }

    private func moveDrag(to point: NSPoint) {
        guard isDragging else { return }
        panel.setFrameOrigin(NSPoint(x: point.x - dragOffset.width, y: point.y - dragOffset.height))
    }

    /// Dropping snaps the rail to the nearer side of whichever screen the pointer is on.
    private func endDrag(at point: NSPoint) {
        guard isDragging else { return }
        isDragging = false
        NSCursor.pop()
        hover.isEnabled = true

        if let screen = NSScreen.screens.first(where: { NSMouseInRect(point, $0.frame, false) }) ?? currentScreen() {
            place(on: screen, side: RailLayout.nearestSide(pointerX: point.x, in: screen.frame))
        } else {
            reposition(animated: true)
        }
    }

    /// Moves the rail to a side of a screen and remembers the choice.
    func place(on screen: NSScreen, side: RailSide) {
        screenNumber = Self.number(of: screen)
        metrics.side = side
        if persistsPlacement {
            let defaults = UserDefaults.standard
            defaults.set(side.rawValue, forKey: Self.sideKey)
            if let screenNumber { defaults.set(NSNumber(value: screenNumber), forKey: Self.screenKey) }
        }
        reposition(animated: true)
    }

    /// Whether the rail currently sits on this side of this screen.
    func isPlaced(on screen: NSScreen, side: RailSide) -> Bool {
        currentScreen() == screen && metrics.side == side
    }

    private func collapsedSize(_ layout: RailLayout) -> CGSize {
        CGSize(width: RailLayout.tabWidth + Self.collapsedMargin,
               height: max(1, layout.railHeight + Self.collapsedMargin))
    }

    private func applyFrame(expanded: Bool, animated: Bool = false, display: Bool = true) {
        guard !isDragging, let screen = currentScreen() else { return }
        let visible = screen.visibleFrame
        let layout = RailLayout.compute(noteCount: model.store.notes.count, available: metrics.available)
        let size = expanded
            ? CGSize(width: RailLayout.cardWidth + Self.expandedMargin, height: metrics.available)
            : collapsedSize(layout)
        let frame = RailLayout.panelFrame(in: visible, side: metrics.side, size: size)
        if panel.frame != frame {
            panel.setFrame(frame, display: display, animate: animated)
        }
    }

    // Clicking anywhere else takes key away from the panel: that saves the edit.
    func windowDidResignKey(_ notification: Notification) {
        // Keep text still being composed by an input method instead of dropping it.
        if let text = editorTextView(), text.hasMarkedText() { text.unmarkText() }
        model.commitEdit()
    }
}
