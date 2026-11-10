import XCTest
@testable import StickyCore

final class NoteTests: XCTestCase {
    func testCap() {
        XCTAssertEqual(Note(text: "少即是多", color: .sky).cap, "少")
        XCTAssertEqual(Note(text: "git commit", color: .sky).cap, "G")
        XCTAssertEqual(Note(text: "  \n hello", color: .sky).cap, "H")
        XCTAssertEqual(Note(text: "👨‍👩‍👧 family", color: .sky).cap, "👨‍👩‍👧")
        XCTAssertEqual(Note(text: "é", color: .sky).cap, "É")
        XCTAssertEqual(Note(text: "   ", color: .sky).cap, "·")
    }
    func testCopyText() {
        XCTAssertEqual(Note(text: "\n a b \n", color: .sky).copyText, "a b")
    }
    func testColorCycle() {
        XCTAssertEqual(NoteColor.allCases, [.sky, .cyan, .lavender, .coral, .gold, .sun])
        XCTAssertEqual(NoteColor.sky.next, .cyan)
        XCTAssertEqual(NoteColor.sun.next, .sky)
        XCTAssertEqual(NoteColor.coral.hex, "#e59fb1")
    }
    func testCodableRoundTrip() throws {
        let n = Note(text: "x", color: .gold)
        let d = try JSONEncoder().encode([n])
        XCTAssertEqual(try JSONDecoder().decode([Note].self, from: d), [n])
    }
}
