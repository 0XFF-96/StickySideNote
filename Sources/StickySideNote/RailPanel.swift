import AppKit
import SwiftUI
import Combine
import StickyCore

/// Borderless floating panel that can take keyboard focus (for editing) without activating the app.
final class RailPanel: NSPanel {
    override var canBecomeKey: Bool { true }
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
        panel.contentView = FirstMouseHostingView(
            rootView: RailView(model: model, metrics: metrics, hover: hover))

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
            guard let self, event.keyCode == 53, self.model.editingID != nil else { return event }
            self.model.commitEdit()
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
    func reposition() {
        guard let screen = NSScreen.screens.first else { return }
        let visible = screen.visibleFrame
        let available = visible.height * (1 - RailLayout.topFraction) - RailLayout.bottomMargin
        if metrics.available != available { metrics.available = available }
        if metrics.screenHeight != visible.height { metrics.screenHeight = visible.height }
        applyFrame(expanded: model.isExpanded)
    }

    private func sync() {
        if model.isHidden {
            hide()
            return
        }
        if !panel.isVisible { panel.orderFrontRegardless() }

        let editing = model.editingID != nil
        if editing && !wasEditing {
            beginKeyboardFocus()
        } else if !editing && wasEditing {
            endKeyboardFocus()
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
        panel.makeKey()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self, self.model.editingID != nil, !self.panel.isKeyWindow else { return }
            self.previousApp = NSWorkspace.shared.frontmostApplication
            NSApp.activate(ignoringOtherApps: true)
            self.panel.makeKeyAndOrderFront(nil)
        }
    }

    private func endKeyboardFocus() {
        // Only give focus back if we still hold it: if the user clicked another app to
        // finish editing, that app is already where they want to be.
        if let previousApp, NSApp.isActive {
            previousApp.activate()
        }
        previousApp = nil
    }

    private func applyFrame(expanded: Bool) {
        guard let screen = NSScreen.screens.first else { return }
        let visible = screen.visibleFrame
        let layout = RailLayout.compute(noteCount: model.store.notes.count, available: metrics.available)
        let size = expanded
            ? CGSize(width: RailLayout.cardWidth + Self.expandedMargin, height: metrics.available)
            : CGSize(width: RailLayout.tabWidth + Self.collapsedMargin,
                     height: max(1, layout.railHeight + Self.collapsedMargin))
        let top = visible.maxY - visible.height * RailLayout.topFraction
        let frame = NSRect(x: visible.minX, y: top - size.height, width: size.width, height: size.height)
        if panel.frame != frame {
            panel.setFrame(frame, display: true)
        }
    }

    // Clicking anywhere else takes key away from the panel: that saves the edit.
    func windowDidResignKey(_ notification: Notification) {
        model.commitEdit()
    }
}
