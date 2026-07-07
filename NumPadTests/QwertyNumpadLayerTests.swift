import XCTest
@testable import NumPad

final class QwertyNumpadLayerTests: XCTestCase {

    private func digits(in rows: [QwertyRow]) -> [String] {
        rows.flatMap { $0.keys }.compactMap {
            if case .character(let s, _) = $0.kind, s.count == 1, s.first!.isNumber { return s }
            return nil
        }
    }

    private func layer(switchKey: Bool = false, dismiss: Bool = false) -> [QwertyRow] {
        QwertyNumpadLayer.rows(needsSwitchKey: switchKey, needsDismissKey: dismiss)
    }

    func testAllTenDigitsAlwaysPresent() {
        for needsSwitch in [true, false] {
            for dismiss in [true, false] {
                let rows = layer(switchKey: needsSwitch, dismiss: dismiss)
                XCTAssertEqual(Set(digits(in: rows)),
                               Set(["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]))
            }
        }
    }

    func testBackspaceReturnAndDecimalPresent() {
        let kinds = layer().flatMap { $0.keys.map { $0.kind } }
        XCTAssertTrue(kinds.contains(.backspace))
        XCTAssertTrue(kinds.contains(.ret))
        XCTAssertTrue(kinds.contains(.character(".", shifted: ".")))
    }

    func testGlobePresenceFollowsNeedsSwitchKey() {
        let with = layer(switchKey: true).flatMap { $0.keys.map { $0.kind } }
        XCTAssertTrue(with.contains(.globe))
        let without = layer().flatMap { $0.keys.map { $0.kind } }
        XCTAssertFalse(without.contains(.globe))
    }

    func testDismissKeyPresenceFollowsNeedsDismissKey() {
        for switchKey in [true, false] {
            XCTAssertEqual(layer(switchKey: switchKey, dismiss: true).last?.keys.last?.kind,
                           .dismissKeyboard, "dismiss key trails the bottom row on iPad")
            XCTAssertFalse(layer(switchKey: switchKey).flatMap { $0.keys }
                .contains { $0.kind == .dismissKeyboard })
        }
    }

    func testEveryRowSumsToUnitWidth() {
        for needsSwitch in [true, false] {
            for dismiss in [true, false] {
                for (i, row) in layer(switchKey: needsSwitch, dismiss: dismiss).enumerated() {
                    let total = row.keys.reduce(0) { $0 + $1.width } + row.leadingMargin + row.trailingMargin
                    XCTAssertEqual(total, QwertyLayout.rowUnitWidth, accuracy: 0.0001,
                                   "row \(i), needsSwitch=\(needsSwitch) dismiss=\(dismiss)")
                }
            }
        }
    }
}
