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
    func testNearestSide() {
        let screen = CGRect(x: 1440, y: -111, width: 1512, height: 950)
        XCTAssertEqual(RailLayout.nearestSide(pointerX: 1500, in: screen), .left)
        XCTAssertEqual(RailLayout.nearestSide(pointerX: 2900, in: screen), .right)
        XCTAssertEqual(RailLayout.nearestSide(pointerX: 2196, in: screen), .left)   // exact middle
        XCTAssertEqual(RailLayout.nearestSide(pointerX: 2197, in: screen), .right)
    }
    func testPanelFrameLeftAndRight() {
        let visible = CGRect(x: 1440, y: 0, width: 1000, height: 1000)
        let size = CGSize(width: 40, height: 200)
        // Top of the rail sits 13% down from the top of the usable area on either side.
        XCTAssertEqual(RailLayout.panelFrame(in: visible, side: .left, size: size),
                       CGRect(x: 1440, y: 670, width: 40, height: 200))
        XCTAssertEqual(RailLayout.panelFrame(in: visible, side: .right, size: size),
                       CGRect(x: 2400, y: 670, width: 40, height: 200))
    }
    func testSideIsCodable() throws {
        let data = try JSONEncoder().encode([RailSide.left, .right])
        XCTAssertEqual(String(data: data, encoding: .utf8), #"["left","right"]"#)
    }
    func testMagnetSide() {
        let screen = CGRect(x: 1440, y: 0, width: 1000, height: 800)
        XCTAssertEqual(RailLayout.magnetSide(pointerX: 1440, in: screen, threshold: 90), .left)
        XCTAssertEqual(RailLayout.magnetSide(pointerX: 1530, in: screen, threshold: 90), .left)
        XCTAssertNil(RailLayout.magnetSide(pointerX: 1531, in: screen, threshold: 90))
        XCTAssertNil(RailLayout.magnetSide(pointerX: 1940, in: screen, threshold: 90))
        XCTAssertNil(RailLayout.magnetSide(pointerX: 2349, in: screen, threshold: 90))
        XCTAssertEqual(RailLayout.magnetSide(pointerX: 2350, in: screen, threshold: 90), .right)
        XCTAssertEqual(RailLayout.magnetSide(pointerX: 2440, in: screen, threshold: 90), .right)
    }
}
