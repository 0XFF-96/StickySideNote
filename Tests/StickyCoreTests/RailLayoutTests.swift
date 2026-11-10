import XCTest
@testable import StickyCore

final class RailLayoutTests: XCTestCase {
    func testFitsAtFullSize() {
        let l = RailLayout.compute(noteCount: 4, available: 700)
        XCTAssertEqual(l.tabHeight, 52); XCTAssertEqual(l.gap, 8)
        XCTAssertTrue(l.canAdd)
        XCTAssertEqual(l.railHeight, 4 * 60 + 32)
    }
    func testFullHidesAdd() {
        let l = RailLayout.compute(noteCount: 11, available: 700)
        XCTAssertEqual(l.tabHeight, 52)
        XCTAssertFalse(l.canAdd)
    }
    func testShrinksToFit() {
        let l = RailLayout.compute(noteCount: 20, available: 700)
        XCTAssertFalse(l.canAdd)
        XCTAssertEqual(l.tabHeight, 52 * 700 / 1200, accuracy: 0.001)
        XCTAssertLessThanOrEqual(20 * (l.tabHeight + l.gap), 700.001)
        XCTAssertLessThanOrEqual(l.railHeight, 700.001)
    }
    func testMinTabHeight() {
        XCTAssertEqual(RailLayout.compute(noteCount: 200, available: 700).tabHeight, 14)
    }
    func testZeroNotes() {
        let l = RailLayout.compute(noteCount: 0, available: 700)
        XCTAssertTrue(l.canAdd); XCTAssertEqual(l.railHeight, 32)
    }
    func testTabTop() {
        XCTAssertEqual(RailLayout.compute(noteCount: 4, available: 700).tabTop(2), 120)
    }
    func testCardShiftsUpNearBottom() {
        let l = RailLayout.compute(noteCount: 11, available: 700)
        XCTAssertEqual(l.tabTop(10), 600)
        XCTAssertEqual(l.cardTop(index: 10, cardHeight: 260, available: 700), 440)
        XCTAssertEqual(l.cardTop(index: 10, cardHeight: 900, available: 700), 0)
        XCTAssertEqual(l.cardTop(index: 1, cardHeight: 100, available: 700), 60)
    }
}
