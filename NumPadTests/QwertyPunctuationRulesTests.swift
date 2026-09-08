import XCTest
@testable import NumPad

final class QwertyPunctuationRulesTests: XCTestCase {
    func testLiteralCodeKeepsASCIIClosingQuoteAndIntentionalSpace() {
        XCTAssertEqual(QwertyPunctuationRules.decision(
            before: "'hello", inserting: "'", smartQuotes: false, adjustsSpacing: false),
                       .init(deletions: 0, insertion: "'"))
        XCTAssertEqual(QwertyPunctuationRules.decision(
            before: "value ", inserting: ":", smartQuotes: false, adjustsSpacing: false),
                       .init(deletions: 0, insertion: ":"))
        XCTAssertEqual(QwertyPunctuationRules.decision(
            before: "print(\"hello", inserting: "\"", smartQuotes: false),
                       .init(deletions: 0, insertion: "\""))
    }

    func testSmartQuotesOptOutDoesNotDisableProseSpacingCleanup() {
        XCTAssertEqual(QwertyPunctuationRules.decision(
            before: "Hello ", inserting: ",", smartQuotes: false),
                       .init(deletions: 1, insertion: ","))
    }

    func test_removesSpaceBeforePunctuation() {
        let d = QwertyPunctuationRules.decision(before: "Hello ", inserting: ".")
        XCTAssertEqual(d, .init(deletions: 1, insertion: "."))
    }

    func test_curlyApostropheInContraction() {
        let d = QwertyPunctuationRules.decision(before: "don", inserting: "'")
        XCTAssertEqual(d.insertion, "’")
    }

    func test_closingQuoteAfterOpening() {
        let d = QwertyPunctuationRules.decision(before: "“Hello", inserting: "\"")
        XCTAssertEqual(d.insertion, "”")
    }
}
