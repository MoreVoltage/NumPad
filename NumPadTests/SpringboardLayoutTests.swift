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
    func test_insertionIndex_clampsHorizontalOvershootToEndOfRow() {
        let i = SpringboardLayout.insertionIndex(at: CGPoint(x: 460, y: 5),
            cell: .init(width: 60, height: 46), spacing: 6, columns: 5, count: 10)
        XCTAssertEqual(i, 5)   // end-of-row, not 7 (row 1 col 2)
    }
    func test_insertionIndex_clampsToCount() {
        let i = SpringboardLayout.insertionIndex(at: CGPoint(x: 9999, y: 9999),
            cell: .init(width: 60, height: 46), spacing: 6, columns: 5, count: 10)
        XCTAssertEqual(i, 10)
    }
    func test_insertionIndex_clampsNegativeToZero() {
        let i = SpringboardLayout.insertionIndex(at: CGPoint(x: -100, y: -100),
            cell: .init(width: 60, height: 46), spacing: 6, columns: 5, count: 10)
        XCTAssertEqual(i, 0)
    }
    func test_moving_outOfRangeFromIsNoOp() {
        let items = (0..<4).map { KeyDefinition(primary: .digit("\($0)")) }
        XCTAssertEqual(SpringboardLayout.moving(items, from: 99, to: 0).map(\.primary), items.map(\.primary))
    }
    func test_moving_toPastCountAppends() {
        let items = (0..<4).map { KeyDefinition(primary: .digit("\($0)")) }
        let moved = SpringboardLayout.moving(items, from: 0, to: 99)
        XCTAssertEqual(moved.map(\.primary.displayLabel), ["1","2","3","0"])
    }
    func test_rebuild_shortLastRowAndEmpty() {
        let seven = (0..<7).map { KeyDefinition(primary: .digit("\($0 % 10)")) }
        XCTAssertEqual(SpringboardLayout.rebuild(seven, columns: 5).map { $0.count }, [5, 2])
        XCTAssertTrue(SpringboardLayout.rebuild([]).isEmpty)
    }
}
