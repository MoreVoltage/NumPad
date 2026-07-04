import XCTest
@testable import NumPad

final class CustomKeyboardKeyLibraryTests: XCTestCase {
    // MARK: Catalog contents (palette-token -> slot assignment source of truth)

    func testChipsIncludeMandatoryDateAndTimeTokensFirst() {
        let chips = CustomKeyboardKeyLibrary.chips
        XCTAssertEqual(chips[0].token, DateTimeTokens.keyToken(for: "date"))
        XCTAssertEqual(chips[0].label, "Date")
        XCTAssertEqual(chips[0].subtitle, Snippet.dateToken)
        XCTAssertEqual(chips[1].token, DateTimeTokens.keyToken(for: "time"))
        XCTAssertEqual(chips[1].label, "Time")
        XCTAssertEqual(chips[1].subtitle, Snippet.timeToken)
    }

    func testChipsIncludeExistingActionTokenStrings() {
        // Reuses CustomKeys' own vocabulary, not new literals — a chip dropped here must behave
        // identically to picking the same token for a right-side slot.
        let tokens = CustomKeyboardKeyLibrary.chips.map(\.token)
        XCTAssertTrue(tokens.contains(CustomKeys.cursorLeftToken))
        XCTAssertTrue(tokens.contains(CustomKeys.cursorRightToken))
        XCTAssertTrue(tokens.contains(CustomKeys.tabToken))
        XCTAssertTrue(tokens.contains(CustomKeys.dismissToken))
    }

    func testChipsIncludeCuratedCharacters() {
        let tokens = CustomKeyboardKeyLibrary.chips.map(\.token)
        for character in CustomKeyboardKeyLibrary.curatedCharacters {
            XCTAssertTrue(tokens.contains(character), "missing curated character chip: \(character)")
        }
    }

    func testEveryChipLabelMatchesCustomKeysDisplayName() {
        // The chip's label and the slot's rendered label must never diverge — otherwise a dropped
        // chip would visually change once it lands.
        for chip in CustomKeyboardKeyLibrary.chips {
            XCTAssertEqual(chip.label, CustomKeys.displayName(for: chip.token),
                            "chip \(chip.token) label must match the slot's own displayed label")
        }
    }

    // MARK: Visibility (drag-disabled hides the palette; legacy static rows are unaffected)

    func testVisibleWhenDragReorderActive() {
        XCTAssertTrue(CustomKeyboardKeyLibrary.isVisible(dragReorderActive: true))
    }

    func testHiddenWhenDragReorderInactive() {
        XCTAssertFalse(CustomKeyboardKeyLibrary.isVisible(dragReorderActive: false))
    }

    // MARK: token -> Item/keycap-label mapping (CustomKeys.displayName's date/time fallback)

    func testDisplayNameResolvesWrappedDateTimeTokenToPackLabel() {
        XCTAssertEqual(CustomKeys.displayName(for: DateTimeTokens.keyToken(for: "date")), "Date")
        XCTAssertEqual(CustomKeys.displayName(for: DateTimeTokens.keyToken(for: "time")), "Time")
    }

    func testDisplayNameFallsBackToRawTokenForUnrecognizedWrappedKey() {
        XCTAssertEqual(CustomKeys.displayName(for: "{dt:bogus}"), "{dt:bogus}")
    }

    func testDisplayNameUnaffectedForOrdinaryCharacters() {
        XCTAssertEqual(CustomKeys.displayName(for: "€"), "€")
    }
}
