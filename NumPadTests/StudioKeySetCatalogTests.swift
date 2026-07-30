//
//  StudioKeySetCatalogTests.swift
//  NumPadTests
//

import XCTest
@testable import NumPad

final class StudioKeySetCatalogTests: XCTestCase {
    func test_visibleChoicesPresentTheApprovedSevenPlainLanguageKeySets() {
        let choices = StudioKeySetCatalog().visibleChoices

        XCTAssertEqual(choices.map(\.title), [
            "Numbers",
            "Calculations",
            "Prices",
            "Measurements",
            "Date & time",
            "Symbols",
            "Programming"
        ])
        XCTAssertEqual(choices.map(\.description), [
            "Clean number entry with basic symbols",
            "Operators, percent, and parentheses",
            "Currency symbols and finance keys",
            "Units and quick conversions",
            "Insert today's date or the time",
            "Common punctuation and marks",
            "Hex and bitwise operators"
        ])
    }

    func test_calculationsRepresentsBothMathLayoutsWithoutDuplicateTiles() {
        let choices = StudioKeySetCatalog().visibleChoices
        let calculations = try! XCTUnwrap(choices.first { $0.title == "Calculations" })

        XCTAssertEqual(choices.filter { $0.title == "Calculations" }.count, 1)
        XCTAssertEqual(calculations.packs, [.math, .math2])
        XCTAssertTrue(calculations.isSelected(for: .math))
        XCTAssertTrue(calculations.isSelected(for: .math2))
        XCTAssertFalse(choices.contains { $0.packs.contains(.cooking) })
    }

    func test_dateAndTimeAndPaidChoicesUseTheirActualPackLockStates() {
        let lockedPacks: Set<KeyboardType> = [.finance, .datetime, .programmer]
        let choices = StudioKeySetCatalog(isLocked: { lockedPacks.contains($0) }).visibleChoices

        XCTAssertFalse(try! XCTUnwrap(choices.first { $0.title == "Numbers" }).isLocked)
        XCTAssertFalse(try! XCTUnwrap(choices.first { $0.title == "Calculations" }).isLocked)
        XCTAssertTrue(try! XCTUnwrap(choices.first { $0.title == "Prices" }).isLocked)
        XCTAssertTrue(try! XCTUnwrap(choices.first { $0.title == "Date & time" }).isLocked)
        XCTAssertTrue(try! XCTUnwrap(choices.first { $0.title == "Programming" }).isLocked)
    }
}
