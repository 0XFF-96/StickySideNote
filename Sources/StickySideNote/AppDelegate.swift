import AppKit
import ServiceManagement
import StickyCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var model: RailModel!
    private var panelController: PanelController!
    private var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        Theme.registerFonts()
        let snapshotDir = Snapshot.directory
        // Snapshot runs use their own notes file so they never touch real notes.
        let store = NoteStore(fileURL: snapshotDir?.appendingPathComponent("notes.json") ?? NoteStore.defaultURL)
        model = RailModel(store: store) { text in
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
        }
        panelController = PanelController(model: model)
        panelController.show()
        if let snapshotDir {
            panelController.hover.isEnabled = false
            if ProcessInfo.processInfo.environment["STICKY_SNAPSHOT_SIDE"] == "right" {
                panelController.preview(side: .right)
            }
            Snapshot.run(model: model, panel: panelController.panel, into: snapshotDir)
            return
        }
        installStatusItem()
        applyLoginDefaultOnce()
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.commitEdit()
    }

    // MARK: Menu bar

    private func installStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let image = NSImage(systemSymbolName: "note.text", accessibilityDescription: "StickySideNote")
        image?.isTemplate = true
        statusItem.button?.image = image
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        statusItem.menu = menu
    }

    /// Rebuilt each time it opens so titles and states are current.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let layout = RailLayout.compute(noteCount: model.store.notes.count,
                                        available: panelController.availableHeight)
        let add = ClosureMenuItem(title: "新建便签") { [unowned self] in
            model.setHidden(false)
            model.addNote()
        }
        add.isEnabled = layout.canAdd
        menu.addItem(add)

        let hidden = model.isHidden
        menu.addItem(ClosureMenuItem(title: hidden ? "显示全部便签" : "隐藏全部便签") { [unowned self] in
            model.setHidden(!hidden)
        })
        menu.addItem(.separator())

        let login = ClosureMenuItem(title: "开机自动启动") { [unowned self] in toggleLoginItem() }
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)
        menu.addItem(.separator())

        menu.addItem(ClosureMenuItem(title: "退出") { NSApp.terminate(nil) })
    }

    // MARK: Launch at login

    private func toggleLoginItem() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("StickySideNote: could not change the login item: \(error)")
        }
    }

    /// Launch at login is on by default, but only for the copy installed in /Applications,
    /// so a development build never registers itself.
    private func applyLoginDefaultOnce() {
        let key = "didApplyLoginDefault"
        guard !UserDefaults.standard.bool(forKey: key),
              Bundle.main.bundlePath.hasPrefix("/Applications/") else { return }
        do {
            try SMAppService.mainApp.register()
            UserDefaults.standard.set(true, forKey: key)
        } catch {
            NSLog("StickySideNote: could not register the login item: \(error)")
        }
    }
}
