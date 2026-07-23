import XCTest
@testable import NumPad

final class QwertyPunctuationRulesTests: XCTestCase {
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
