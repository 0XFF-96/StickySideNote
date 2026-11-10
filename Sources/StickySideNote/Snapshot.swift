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

    private static func write(_ panel: NSPanel, to url: URL) {
        guard let view = panel.contentView,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        let frame = panel.frame
        print("\(url.lastPathComponent): panel \(Int(frame.width))x\(Int(frame.height)) key=\(panel.isKeyWindow)")
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
    }
}
