import XCTest
@testable import NumPad

final class CustomKeyboardLayoutTests: XCTestCase {

    private func config(top: [String]? = nil, c1: [String]? = nil, c2: [String]? = nil) -> CustomKeyboardConfig {
        CustomKeyboardConfig(topRow: top, column1: c1, column2: c2)
    }
    private func bottomRow(_ rows: [[CustomKeyboardCell]]) -> [CustomKeyboardCell] { rows.last ?? [] }
    private func build(_ cfg: CustomKeyboardConfig, _ handed: Handedness = .right,
                       switchKey: Bool = false, reversed: Bool = false) -> [[CustomKeyboardCell]] {
        CustomKeyboardLayout.bodyRows(for: cfg, handedness: handed, needsSwitchKey: switchKey, reversed: reversed)
    }

    // MARK: digits 0–9 are always fixed (never editable, never droppable)
    func testAllDigitsAlwaysPresent() {
        let flat = build(config(c1: ["x"])).flatMap { $0 }
        for d in (1...9).map(String.init) {
            XCTAssertTrue(flat.contains(.digit(d)), "digit \(d) must always render")
        }
        XCTAssertTrue(flat.contains(.zero))
    }

    // MARK: globe guard — the disappearing-globe bug must not recur
    func testSwitchKeyAlwaysPresentWhenNeeded() {
        for handed in Handedness.allCases {
            for cfg in [config(), config(c1: ["a"], c2: ["b"]), config(top: ["00"])] {
                let withSwitch = build(cfg, handed, switchKey: true)
                XCTAssertTrue(bottomRow(withSwitch).contains(.globe), "globe must be present when needed")
                XCTAssertTrue(bottomRow(withSwitch).contains(.next), "next key always present")
                let without = build(cfg, handed, switchKey: false)
                XCTAssertFalse(bottomRow(without).contains(.globe))
                XCTAssertTrue(bottomRow(without).contains(.next))
            }
        }
    }

    func testReturnAndBackAlwaysPresent() {
        let bottom = bottomRow(build(config()))
        XCTAssertTrue(bottom.contains(.ret))
        XCTAssertTrue(bottom.contains(.back))
    }

    // MARK: handedness places the columns on the correct side (Column 1 nearest the digits)
    func testRightHandedColumnsAfterDigits() {
        let rows = build(config(c1: ["A", "B", "C"], c2: ["D", "E", "F"]), .right)
        XCTAssertEqual(rows[0], [.digit("1"), .digit("2"), .digit("3"), .peripheral("A"), .peripheral("D")])
    }

    func testLeftHandedColumnsBeforeDigits() {
        let rows = build(config(c1: ["A", "B", "C"], c2: ["D", "E", "F"]), .left)
        XCTAssertEqual(rows[0], [.peripheral("D"), .peripheral("A"), .digit("1"), .digit("2"), .digit("3")])
    }

    // MARK: builder is body-only — the top row is the keyboard's (pack-aware) job
    func testBuilderIgnoresConfigTopRow() {
        // Even with a config top row set, bodyRows starts at the first number row; the top row is
        // assembled separately (pack-aware) by the keyboard.
        let rows = build(config(top: ["00", "000"], c1: ["x"]))
        XCTAssertEqual(Array(rows[0].prefix(3)), [.digit("1"), .digit("2"), .digit("3")])
        XCTAssertEqual(rows[0].last, .peripheral("x"))   // column still rendered
    }

    // MARK: short columns are padded with blanks; empty columns contribute nothing
    func testShortColumnPaddedWithBlanks() {
        let rows = build(config(c1: ["A"]))
        XCTAssertEqual(rows[0].last, .peripheral("A"))
        XCTAssertEqual(rows[1].last, .blank)
        XCTAssertEqual(rows[2].last, .blank)
    }

    func testEmptyColumnContributesNoCells() {
        let rows = build(config(c1: ["", ""]))
        XCTAssertEqual(rows[0], [.digit("1"), .digit("2"), .digit("3")])
    }

    // MARK: reversed flips the digit-row order; columns stay paired by row position
    func testReversedFlipsDigitRows() {
        XCTAssertEqual(Array(build(config()).first!.prefix(3)), [.digit("1"), .digit("2"), .digit("3")])
        XCTAssertEqual(Array(build(config(), reversed: true).first!.prefix(3)), [.digit("7"), .digit("8"), .digit("9")])
    }
}
