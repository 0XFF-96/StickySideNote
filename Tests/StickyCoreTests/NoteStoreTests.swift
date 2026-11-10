import XCTest
@testable import StickyCore

final class NoteStoreTests: XCTestCase {
    var dir: URL!
    var file: URL { dir.appendingPathComponent("notes.json") }

    override func setUp() {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }
    override func tearDown() { try? FileManager.default.removeItem(at: dir) }

    private func backups() -> [URL] {
        let all = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        return all.filter { $0.lastPathComponent.hasPrefix("notes.corrupt-") }
    }
    private func seed(_ data: Data) throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try data.write(to: file)
    }

    func testFirstRunSeedsWelcomeNote() {
        let s = NoteStore(fileURL: file)
        XCTAssertEqual(s.notes.count, 1)
        XCTAssertEqual(s.notes[0].text, "悬停看全文 · 单击复制 · 双击编辑 · 右键换色或删除")
        XCTAssertEqual(s.notes[0].color, .sky)
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
    }

    func testAddPersistsAndCyclesColor() {
        let s = NoteStore(fileURL: file)
        XCTAssertEqual(s.add(text: "a").color, .cyan)
        XCTAssertEqual(s.add(text: "b").color, .lavender)
        let r = NoteStore(fileURL: file)
        XCTAssertEqual(r.notes, s.notes)
        XCTAssertEqual(Array(r.notes.map(\.text).suffix(2)), ["a", "b"])
    }

    func testUpdateSetColorDeletePersist() {
        let s = NoteStore(fileURL: file)
        let a = s.add(text: "a"), b = s.add(text: "b")
        s.updateText(a.id, "a2")
        s.setColor(a.id, .gold)
        s.delete(b.id)
        let r = NoteStore(fileURL: file)
        XCTAssertEqual(r.notes.count, 2)
        XCTAssertEqual(r.notes[1].text, "a2")
        XCTAssertEqual(r.notes[1].color, .gold)
    }

    func testCorruptFileIsBackedUp() throws {
        try seed(Data("{not json".utf8))
        let s = NoteStore(fileURL: file)
        XCTAssertTrue(s.notes.isEmpty)
        XCTAssertEqual(backups().count, 1)
        XCTAssertEqual(try String(contentsOf: backups()[0], encoding: .utf8), "{not json")
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
    }

    func testEmptyFileIsBackedUp() throws {
        try seed(Data())
        let s = NoteStore(fileURL: file)
        XCTAssertTrue(s.notes.isEmpty)
        XCTAssertEqual(backups().count, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
    }

    func testAddAfterCorruptDoesNotTouchBackup() throws {
        try seed(Data("{not json".utf8))
        let s = NoteStore(fileURL: file)
        XCTAssertEqual(s.add(text: "x").color, .sky)
        XCTAssertEqual(try String(contentsOf: backups()[0], encoding: .utf8), "{not json")
        XCTAssertEqual(NoteStore(fileURL: file).notes.map(\.text), ["x"])
    }
}
