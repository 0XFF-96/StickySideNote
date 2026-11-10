import XCTest
@testable import StickyCore

@MainActor
final class RailModelTests: XCTestCase {
    var dir: URL!
    var store: NoteStore!
    var copied: [String] = []
    var model: RailModel!

    override func setUp() async throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        store = NoteStore(fileURL: dir.appendingPathComponent("notes.json"))
        copied = []
        model = RailModel(store: store) { [unowned self] in self.copied.append($0) }
    }
    override func tearDown() async throws { try? FileManager.default.removeItem(at: dir) }

    func testClickCopiesTrimmedText() {
        let n = store.add(text: " a \n")
        model.click(n.id)
        XCTAssertEqual(copied, ["a"])
        XCTAssertEqual(model.copiedID, n.id)
        model.clearCopied(n.id)
        XCTAssertNil(model.copiedID)
    }
    func testClickIgnoredWhileEditing() {
        let n = store.add(text: "a")
        model.beginEdit(n.id)
        model.click(n.id)
        XCTAssertTrue(copied.isEmpty)
    }
    func testAddNoteEntersEdit() {
        let before = store.notes.count
        model.addNote()
        XCTAssertEqual(store.notes.count, before + 1)
        XCTAssertEqual(model.editingID, store.notes.last?.id)
        XCTAssertEqual(model.draft, "")
        XCTAssertTrue(model.isExpanded)
    }
    func testCommitSavesDraft() {
        let n = store.add(text: "旧")
        model.beginEdit(n.id)
        XCTAssertEqual(model.draft, "旧")
        model.draft = "新内容"
        model.commitEdit()
        XCTAssertEqual(store.notes.last?.text, "新内容")
        XCTAssertNil(model.editingID)
    }
    func testCommitEmptyDeletes() {
        let before = store.notes.count
        model.addNote()
        model.commitEdit()
        XCTAssertEqual(store.notes.count, before)
    }
    func testCommitWhitespaceOnlyDeletes() {
        let n = store.add(text: "a")
        model.beginEdit(n.id)
        model.draft = " \n "
        model.commitEdit()
        XCTAssertFalse(store.notes.contains { $0.id == n.id })
    }
    func testCommitOnResign() {
        let n = store.add(text: "a")
        model.beginEdit(n.id)
        model.draft = "半句话"
        model.setHidden(true)
        XCTAssertEqual(store.notes.last?.text, "半句话")
        XCTAssertTrue(model.isHidden)
        XCTAssertNil(model.editingID)
    }
    func testBeginEditCommitsPrevious() {
        let a = store.add(text: "a"), b = store.add(text: "b")
        model.beginEdit(a.id)
        model.draft = "a2"
        model.beginEdit(b.id)
        XCTAssertEqual(store.notes.first { $0.id == a.id }?.text, "a2")
        XCTAssertEqual(model.editingID, b.id)
        XCTAssertEqual(model.draft, "b")
    }
    func testHoverIgnoredWhileEditing() {
        let a = store.add(text: "a"), b = store.add(text: "b")
        model.setHover(a.id)
        XCTAssertEqual(model.hoveredID, a.id)
        model.beginEdit(a.id)
        model.setHover(b.id)
        XCTAssertEqual(model.hoveredID, a.id)
    }
    func testDeleteWhileEditing() {
        let a = store.add(text: "a")
        model.beginEdit(a.id)
        model.delete(a.id)
        XCTAssertNil(model.editingID)
        model.commitEdit()
        XCTAssertFalse(store.notes.contains { $0.id == a.id })
    }
    func testClickOnAnotherNoteWhileEditingSavesTheEdit() {
        let a = store.add(text: "a"), b = store.add(text: "b")
        model.beginEdit(a.id)
        model.draft = "a2"
        model.click(b.id)
        XCTAssertNil(model.editingID)
        XCTAssertEqual(store.notes.first { $0.id == a.id }?.text, "a2")
        XCTAssertTrue(copied.isEmpty)
    }
    func testDraftIsOnDiskBeforeCommit() {
        let a = store.add(text: "a")
        model.beginEdit(a.id)
        model.draft = "typed but not committed"
        let reloaded = NoteStore(fileURL: dir.appendingPathComponent("notes.json"))
        XCTAssertEqual(reloaded.notes.first { $0.id == a.id }?.text, "typed but not committed")
        XCTAssertEqual(model.editingID, a.id)
    }
}
