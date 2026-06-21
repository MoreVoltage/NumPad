import XCTest
@testable import NumPad

final class KeyTokenDisplayTests: XCTestCase {
    func testDigitLabelIsTheDigit() {
        XCTAssertEqual(KeyToken.digit("7").displayLabel, "7")
    }
    func testOperatorLabelIsTheInsertedString() {
        XCTAssertEqual(KeyToken.op("*").displayLabel, "*")
    }
    func testDecimalSeparatorLabelIsDot() {
        XCTAssertEqual(KeyToken.decimalSeparator.displayLabel, ".")
    }
    func testDeleteLabelIsBackspaceGlyph() {
        XCTAssertEqual(KeyToken.delete.displayLabel, "⌫")
    }
    func testReturnAndSpaceUseWords() {
        XCTAssertEqual(KeyToken.ret.displayLabel, "return")
        XCTAssertEqual(KeyToken.space.displayLabel, "space")
    }
}

final class KeyTokenPaletteTests: XCTestCase {
    func testPaletteCoversDigitsZeroThroughNine() {
        for n in 0...9 {
            XCTAssertTrue(KeyTokenPalette.tokens.contains(.digit(String(n))), "palette missing digit \(n)")
        }
    }
    func testPaletteIncludesStandardEditingKeys() {
        for t in [KeyToken.decimalSeparator, .delete, .ret, .space] {
            XCTAssertTrue(KeyTokenPalette.tokens.contains(t), "palette missing \(t)")
        }
    }
    func testPaletteIncludesCommonOperators() {
        for s in ["+", "-", "*", "/", "=", "%"] {
            XCTAssertTrue(KeyTokenPalette.tokens.contains(.op(s)), "palette missing op \(s)")
        }
    }
    func testEveryPaletteTokenRendersNonBlank() {
        // A palette token that renders .blank would let a user add a dead key. Guard it.
        for token in KeyTokenPalette.tokens {
            XCTAssertNotEqual(KeyboardLayoutRenderer.renderKind(for: token), .blank,
                              "palette token \(token) renders blank")
        }
    }
}

final class GridPositionFindingTests: XCTestCase {
    func testPositionOfZeroInStandard() {
        // standard row 3 = [decimalSeparator, "0", delete]. Bind once: `standard` is a
        // computed var that mints fresh UUIDs on each access.
        let layout = KeyboardLayout.standard
        let zero = layout.rows[3][1]
        XCTAssertEqual(layout.position(of: zero.id), GridPosition(row: 3, index: 1))
    }
    func testPositionOfUnknownIsNil() {
        XCTAssertNil(KeyboardLayout.standard.position(of: UUID()))
    }
}

final class ReorderingTests: XCTestCase {
    // standard: row0[7,8,9] row1[4,5,6] row2[1,2,3] row3[.,0,delete] row4[ret]
    private func tokens(_ row: [KeyDefinition]) -> [KeyToken] { row.map(\.primary) }

    func testMoveLaterKeyBeforeEarlierSameRow() {
        let layout = KeyboardLayout.standard
        let sep = layout.rows[3][0]   // decimalSeparator
        let del = layout.rows[3][2]   // delete
        let out = layout.reordering(del.id, before: sep.id)
        XCTAssertEqual(tokens(out.rows[3]), [.delete, .decimalSeparator, .digit("0")])
    }

    func testMoveEarlierKeyBeforeLaterSameRowAdjustsForRemoval() {
        let layout = KeyboardLayout.standard
        let sep = layout.rows[3][0]   // decimalSeparator
        let del = layout.rows[3][2]   // delete
        let out = layout.reordering(sep.id, before: del.id)
        // decimalSeparator should land immediately before delete despite the removal shift
        XCTAssertEqual(tokens(out.rows[3]), [.digit("0"), .decimalSeparator, .delete])
    }

    func testCrossRowMove() {
        let layout = KeyboardLayout.standard
        let seven = layout.rows[0][0]  // "7"
        let one = layout.rows[2][0]    // "1"
        let out = layout.reordering(seven.id, before: one.id)
        XCTAssertEqual(tokens(out.rows[0]), [.digit("8"), .digit("9")])
        XCTAssertEqual(tokens(out.rows[2]), [.digit("7"), .digit("1"), .digit("2"), .digit("3")])
    }

    func testReorderOntoSelfIsNoOp() {
        let layout = KeyboardLayout.standard
        let five = layout.rows[1][1]
        XCTAssertEqual(layout.reordering(five.id, before: five.id), layout)
    }

    func testReorderWithUnknownIdsIsUnchanged() {
        let layout = KeyboardLayout.standard
        XCTAssertEqual(layout.reordering(UUID(), before: layout.rows[0][0].id), layout)
        XCTAssertEqual(layout.reordering(layout.rows[0][0].id, before: UUID()), layout)
    }
}

final class AppendingKeyTests: XCTestCase {
    func testAppendedKeyIsLastInLastRow() {
        let layout = KeyboardLayout.standard
        let key = KeyDefinition(primary: .op("+"))
        let out = layout.appendingKey(key)
        XCTAssertEqual(out.rows.last?.last?.id, key.id)
        XCTAssertEqual(out.rows.count, layout.rows.count, "append goes into the existing last row, not a new one")
    }
}
