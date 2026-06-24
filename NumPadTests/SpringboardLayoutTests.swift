import XCTest
import CoreGraphics
@testable import NumPad

final class SpringboardLayoutTests: XCTestCase {
    func test_flatten_rebuild_roundTrips() {
        let l = KeyboardLayout.standard
        let rows = SpringboardLayout.rebuild(SpringboardLayout.flatten(l))
        XCTAssertEqual(rows.flatMap { $0 }.map(\.primary), l.rows.flatMap { $0 }.map(\.primary))
    }
    func test_moving_reflows() {
        let items = (0..<6).map { KeyDefinition(primary: .digit("\($0)")) }
        let moved = SpringboardLayout.moving(items, from: 0, to: 3)
        XCTAssertEqual(moved.map(\.primary.displayLabel), ["1","2","3","0","4","5"])
    }
    func test_insertionIndex_mapsPointToSlot() {
        let i = SpringboardLayout.insertionIndex(at: CGPoint(x: 130, y: 5),
            cell: .init(width: 60, height: 46), spacing: 6, columns: 5, count: 10)
        XCTAssertEqual(i, 2)
    }
    func test_essentialsLocked() {
        XCTAssertTrue(SpringboardLayout.isLocked(.digit("0")))
        XCTAssertTrue(SpringboardLayout.isLocked(.delete))
        XCTAssertFalse(SpringboardLayout.isLocked(.op("+")))
    }
}
