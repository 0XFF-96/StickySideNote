import Foundation
import Combine

/// Interaction state for the rail: which note is hovered, being edited, or just copied.
@MainActor
public final class RailModel: ObservableObject {
    public let store: NoteStore
    @Published public private(set) var hoveredID: UUID?
    @Published public private(set) var editingID: UUID?
    @Published public private(set) var copiedID: UUID?
    /// Text being edited. Written through to the store on every change, so a crash or a
    /// kill mid-edit loses nothing; `commitEdit` only decides whether a blank note is deleted.
    @Published public var draft: String = "" {
        didSet {
            if let id = editingID, draft != oldValue { store.updateText(id, draft) }
        }
    }
    @Published public private(set) var isHidden = false

    public var isExpanded: Bool { hoveredID != nil || editingID != nil }

    private let copy: (String) -> Void
    private var storeSink: AnyCancellable?

    public init(store: NoteStore, copy: @escaping (String) -> Void) {
        self.store = store
        self.copy = copy
        storeSink = store.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }
    }

    public func setHover(_ id: UUID?) {
        guard editingID == nil else { return }
        hoveredID = id
    }

    public func click(_ id: UUID) {
        if let editing = editingID {
            // A click on another note counts as clicking away: it saves the edit.
            if editing != id { commitEdit() }
            return
        }
        guard let note = note(id) else { return }
        copy(note.copyText)
        copiedID = id
    }

    public func clearCopied(_ id: UUID) {
        if copiedID == id { copiedID = nil }
    }

    public func beginEdit(_ id: UUID) {
        guard editingID != id, let note = note(id) else { return }
        commitEdit()
        draft = note.text
        copiedID = nil
        hoveredID = id
        editingID = id
    }

    public func addNote() {
        commitEdit()
        beginEdit(store.add(text: "").id)
    }

    public func commitEdit() {
        guard let id = editingID else { return }
        editingID = nil
        hoveredID = nil
        if draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            store.delete(id)
        } else {
            store.updateText(id, draft)
        }
        draft = ""
    }

    public func setColor(_ id: UUID, _ color: NoteColor) {
        store.setColor(id, color)
    }

    public func delete(_ id: UUID) {
        if editingID == id { editingID = nil; draft = "" }
        if hoveredID == id { hoveredID = nil }
        store.delete(id)
    }

    public func setHidden(_ hidden: Bool) {
        if hidden { commitEdit() }
        isHidden = hidden
    }

    private func note(_ id: UUID) -> Note? {
        store.notes.first { $0.id == id }
    }
}
