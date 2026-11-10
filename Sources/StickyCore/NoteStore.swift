import Foundation
import Combine

public final class NoteStore: ObservableObject {
    public static let welcomeText = "悬停看全文 · 单击复制 · 双击编辑 · 右键换色或删除"

    public static var defaultURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("StickySideNote", isDirectory: true)
            .appendingPathComponent("notes.json")
    }

    @Published public private(set) var notes: [Note] = []
    private let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
        let fm = FileManager.default
        guard fm.fileExists(atPath: fileURL.path) else {
            notes = [Note(text: Self.welcomeText, color: .sky)]
            save()
            return
        }
        do {
            // A blank note is one whose edit never finished (the app was killed mid-edit).
            notes = try Self.decoder.decode([Note].self, from: Data(contentsOf: fileURL))
                .filter { !$0.copyText.isEmpty }
        } catch {
            // Never overwrite a file we could not read: move it aside and start empty.
            let backup = fileURL.deletingLastPathComponent()
                .appendingPathComponent("notes.corrupt-\(Int(Date().timeIntervalSince1970)).json")
            do { try fm.moveItem(at: fileURL, to: backup) }
            catch { NSLog("StickySideNote: could not back up unreadable notes file: \(error)") }
            notes = []
        }
    }

    @discardableResult
    public func add(text: String) -> Note {
        let note = Note(text: text, color: notes.last?.color.next ?? .sky)
        notes.append(note)
        save()
        return note
    }

    public func updateText(_ id: UUID, _ text: String) {
        guard let i = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[i].text = text
        save()
    }

    public func setColor(_ id: UUID, _ color: NoteColor) {
        guard let i = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[i].color = color
        save()
    }

    public func delete(_ id: UUID) {
        notes.removeAll { $0.id == id }
        save()
    }

    private static let decoder = JSONDecoder()

    private func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try encoder.encode(notes).write(to: fileURL, options: .atomic)
        } catch {
            NSLog("StickySideNote: could not save notes: \(error)")
        }
    }
}
