import AppKit
import StickyCore

/// Development aid: with STICKY_SNAPSHOT_DIR set, the app drives itself through the main
/// states and writes a PNG of the panel for each, then quits. Lets the look be checked
/// without screen-recording permission. Never runs in normal use.
@MainActor
enum Snapshot {
    static var directory: URL? {
        ProcessInfo.processInfo.environment["STICKY_SNAPSHOT_DIR"].map { URL(fileURLWithPath: $0) }
    }

    static func run(model: RailModel, panel: NSPanel, into dir: URL) {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let notes = model.store.notes
        var steps: [(String, () -> Void)] = [("1-idle", {})]
        if let first = notes.first {
            steps.append(("2-hover-first", { model.setHover(first.id) }))
            steps.append(("3-copied", { model.click(first.id) }))
        }
        if let last = notes.last {
            steps.append(("4-hover-last", { model.clearCopied(notes[0].id); model.setHover(last.id) }))
            steps.append(("5-edit-last", { model.beginEdit(last.id) }))
            steps.append(("6-committed", { model.commitEdit() }))
        }
        for (i, step) in steps.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1 + Double(i)) {
                step.1()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                    write(panel, to: dir.appendingPathComponent("\(step.0).png"))
                    if i == steps.count - 1 { NSApp.terminate(nil) }
                }
            }
        }
    }

    /// Drives the drag callbacks to the far side of every screen in turn and prints where the
    /// panel ends up. Checks the placement logic; it cannot check real mouse delivery.
    static func dragAcrossScreens(_ controller: PanelController) {
        let panel = controller.panel
        var delay = 1.0
        for screen in NSScreen.screens.reversed() {
            for fraction in [0.99, 0.6, 0.01] {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    let start = NSPoint(x: panel.frame.midX, y: panel.frame.midY)
                    let target = NSPoint(x: screen.frame.minX + screen.frame.width * fraction, y: screen.frame.midY)
                    controller.drag.onBegan(start)
                    controller.drag.onMoved(target)
                    print("dragging over \(screen.localizedName): panel at \(panel.frame)")
                    controller.drag.onEnded(target)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.8) {
                    print("dropped at \(fraction) of \(screen.localizedName): panel \(panel.frame) on \(panel.screen?.localizedName ?? "no screen"), visible \(screen.visibleFrame)")
                }
                delay += 1.2
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { NSApp.terminate(nil) }
    }

    private static func write(_ panel: NSPanel, to url: URL) {
        guard let view = panel.contentView,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        let frame = panel.frame
        print("\(url.lastPathComponent): panel \(Int(frame.width))x\(Int(frame.height)) key=\(panel.isKeyWindow)")
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
    }
}
