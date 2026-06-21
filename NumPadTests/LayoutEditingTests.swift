import XCTest
@testable import NumPad

final class LayoutEditingTests: XCTestCase {
    /// row0: [1, 2]   row1: [3]
    private func makeLayout() -> KeyboardLayout {
        KeyboardLayout(name: "t", rows: [
            [KeyDefinition(primary: .digit("1")), KeyDefinition(primary: .digit("2"))],
            [KeyDefinition(primary: .digit("3"))],
        ])
    }
    private func ids(_ l: KeyboardLayout) -> [UUID] { l.rows.flatMap { $0 }.map(\.id) }

    func testRemovingKey() {
        let l = makeLayout(); let target = l.rows[0][1].id
        let r = l.removingKey(target)
        XCTAssertFalse(ids(r).contains(target))
        XCTAssertEqual(ids(r).count, 2)
    }

    func testRemovingUnknownIdIsNoChange() {
        let l = makeLayout()
        XCTAssertEqual(l.removingKey(UUID()), l)
    }

    func testUpdatingKeyAppliesToMatchOnly() {
        let l = makeLayout(); let target = l.rows[0][0].id
        let r = l.updatingKey(target) { $0.label = "X"; $0.columnSpan = 2 }
        let updated = r.rows.flatMap { $0 }.first { $0.id == target }!
        XCTAssertEqual(updated.label, "X")
        XCTAssertEqual(updated.columnSpan, 2)
        XCTAssertNil(r.rows[0][1].label)  // sibling untouched
    }

    func testInsertingKeyAtPosition() {
        let l = makeLayout(); let key = KeyDefinition(primary: .op("+"))
        let r = l.insertingKey(key, at: GridPosition(row: 0, index: 1))
        XCTAssertEqual(r.rows[0].map(\.id), [l.rows[0][0].id, key.id, l.rows[0][1].id])
    }

    func testMovingKeyAcrossRows() {
        let l = makeLayout(); let target = l.rows[0][0].id  // "1"
        let r = l.movingKey(target, to: GridPosition(row: 1, index: 0))
        XCTAssertEqual(r.rows[0].count, 1)           // removed from row 0
        XCTAssertEqual(r.rows[1].first?.id, target)  // now first in row 1
        XCTAssertEqual(ids(r).count, 3)              // nothing lost
    }

    func testEditsDoNotMutateSource() {
        let l = makeLayout(); let target = l.rows[0][0].id
        _ = l.removingKey(target)
        _ = l.updatingKey(target) { $0.label = "Z" }
        XCTAssertEqual(ids(l).count, 3)
        XCTAssertNil(l.rows[0][0].label)
    }
}
