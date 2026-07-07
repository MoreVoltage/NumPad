import XCTest
@testable import NumPad

final class QwertyNumpadLayerTests: XCTestCase {

    private func digits(in rows: [QwertyRow]) -> [String] {
        rows.flatMap { $0.keys }.compactMap {
            if case .character(let s, _) = $0.kind, s.count == 1, s.first!.isNumber { return s }
            return nil
        }
    }

    func testAllTenDigitsAlwaysPresent() {
        for needsSwitch in [true, false] {
            let rows = QwertyNumpadLayer.rows(needsSwitchKey: needsSwitch)
            XCTAssertEqual(Set(digits(in: rows)),
                           Set(["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]))
        }
    }

    func testBackspaceReturnAndDecimalPresent() {
        let kinds = QwertyNumpadLayer.rows(needsSwitchKey: false).flatMap { $0.keys.map { $0.kind } }
        XCTAssertTrue(kinds.contains(.backspace))
        XCTAssertTrue(kinds.contains(.ret))
        XCTAssertTrue(kinds.contains(.character(".", shifted: ".")))
    }

    func testGlobePresenceFollowsNeedsSwitchKey() {
        let with = QwertyNumpadLayer.rows(needsSwitchKey: true).flatMap { $0.keys.map { $0.kind } }
        XCTAssertTrue(with.contains(.globe))
        let without = QwertyNumpadLayer.rows(needsSwitchKey: false).flatMap { $0.keys.map { $0.kind } }
        XCTAssertFalse(without.contains(.globe))
    }

    func testEveryRowSumsToUnitWidth() {
        for needsSwitch in [true, false] {
            for (i, row) in QwertyNumpadLayer.rows(needsSwitchKey: needsSwitch).enumerated() {
                let total = row.keys.reduce(0) { $0 + $1.width } + row.leadingMargin + row.trailingMargin
                XCTAssertEqual(total, QwertyLayout.rowUnitWidth, accuracy: 0.0001,
                               "row \(i), needsSwitch=\(needsSwitch)")
            }
        }
    }
}
