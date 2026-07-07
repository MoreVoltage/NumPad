import XCTest
@testable import NumPad

final class DoubleSpacePeriodTests: XCTestCase {

    private func decide(_ before: String?,
                        sinceLastSpace: TimeInterval? = 0.2,
                        enabled: Bool = true) -> DoubleSpacePeriod.Decision {
        DoubleSpacePeriod.decision(before: before,
                                   secondsSinceLastSpaceTap: sinceLastSpace,
                                   enabled: enabled)
    }

    // MARK: the happy path — "word " + quick second space → "word. "

    func testQuickDoubleSpaceAfterWordConverts() {
        XCTAssertEqual(decide("hello "), .replacePreviousSpaceWithPeriodSpace)
    }

    func testConversionWorksAfterDigitsAndClosingCharacters() {
        XCTAssertEqual(decide("42 "), .replacePreviousSpaceWithPeriodSpace)
        XCTAssertEqual(decide("(done) "), .replacePreviousSpaceWithPeriodSpace)
        XCTAssertEqual(decide("\"quote\" "), .replacePreviousSpaceWithPeriodSpace)
    }

    // MARK: guards — every one of these must fall back to a plain space

    func testDisabledSettingInsertsPlainSpace() {
        XCTAssertEqual(decide("hello ", enabled: false), .insertSpace)
    }

    func testSlowSecondSpaceInsertsPlainSpace() {
        XCTAssertEqual(decide("hello ", sinceLastSpace: DoubleSpacePeriod.maxInterval + 0.01),
                       .insertSpace)
        XCTAssertEqual(decide("hello ", sinceLastSpace: nil), .insertSpace,
                       "no prior space tap recorded")
    }

    func testNoTrailingSpaceInsertsPlainSpace() {
        XCTAssertEqual(decide("hello"), .insertSpace)
        XCTAssertEqual(decide(nil), .insertSpace)
        XCTAssertEqual(decide(""), .insertSpace)
    }

    func testTwoExistingSpacesInsertPlainSpace() {
        XCTAssertEqual(decide("hello  "), .insertSpace,
                       "already two spaces — the shortcut fired or was declined; never make three-into-period")
    }

    func testPunctuationBeforeSpaceInsertsPlainSpace() {
        XCTAssertEqual(decide("hello. "), .insertSpace, "already ends a sentence")
        XCTAssertEqual(decide("hello, "), .insertSpace)
        XCTAssertEqual(decide("hello- "), .insertSpace)
        XCTAssertEqual(decide("hello… "), .insertSpace)
    }

    func testSpaceOnlyDocumentInsertsPlainSpace() {
        XCTAssertEqual(decide(" "), .insertSpace, "no word before the space")
    }

    // MARK: the applied edit is exactly delete-one-insert-period-space

    func testDecisionDescribesTheExactEdit() {
        // The keyboard applies .replacePreviousSpaceWithPeriodSpace as: deleteBackward() once,
        // then insertText(". ") — asserted here as the contract the enum name promises.
        XCTAssertEqual(DoubleSpacePeriod.Decision.replacePreviousSpaceWithPeriodSpace.deletions, 1)
        XCTAssertEqual(DoubleSpacePeriod.Decision.replacePreviousSpaceWithPeriodSpace.insertion, ". ")
        XCTAssertEqual(DoubleSpacePeriod.Decision.insertSpace.deletions, 0)
        XCTAssertEqual(DoubleSpacePeriod.Decision.insertSpace.insertion, " ")
    }
}
