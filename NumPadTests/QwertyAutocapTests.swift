import XCTest
@testable import NumPad

final class QwertyAutocapTests: XCTestCase {

    private func capitalizes(_ policy: QwertyAutocapPolicy, _ before: String?) -> Bool {
        QwertyAutocap.shouldCapitalize(policy: policy, before: before)
    }

    // MARK: .none / .allCharacters

    func testNonePolicyNeverCapitalizes() {
        for context in [nil, "", "hello. ", "\n"] as [String?] {
            XCTAssertFalse(capitalizes(.none, context))
        }
    }

    func testAllCharactersPolicyAlwaysCapitalizes() {
        for context in [nil, "", "hello", "mid-word"] as [String?] {
            XCTAssertTrue(capitalizes(.allCharacters, context))
        }
    }

    // MARK: .words

    func testWordsCapitalizesAtStartAndAfterWhitespace() {
        XCTAssertTrue(capitalizes(.words, nil))
        XCTAssertTrue(capitalizes(.words, ""))
        XCTAssertTrue(capitalizes(.words, "hello "))
        XCTAssertTrue(capitalizes(.words, "hello\n"))
        XCTAssertFalse(capitalizes(.words, "hello"))
        XCTAssertFalse(capitalizes(.words, "hello."))
    }

    // MARK: .sentences — the system default

    func testSentencesCapitalizesAtDocumentStart() {
        XCTAssertTrue(capitalizes(.sentences, nil))
        XCTAssertTrue(capitalizes(.sentences, ""))
        XCTAssertTrue(capitalizes(.sentences, "   "), "leading spaces only is still document start")
    }

    func testSentencesCapitalizesAfterTerminatorAndSpace() {
        XCTAssertTrue(capitalizes(.sentences, "Done. "))
        XCTAssertTrue(capitalizes(.sentences, "Done! "))
        XCTAssertTrue(capitalizes(.sentences, "Done? "))
        XCTAssertTrue(capitalizes(.sentences, "Done.  "), "multiple spaces still qualify")
    }

    func testSentencesCapitalizesAfterNewline() {
        XCTAssertTrue(capitalizes(.sentences, "line one\n"))
        XCTAssertTrue(capitalizes(.sentences, "line one\n\n"))
    }

    func testSentencesCapitalizesAfterTerminatorClosingQuoteAndSpace() {
        XCTAssertTrue(capitalizes(.sentences, "He said \"stop.\" "))
        XCTAssertTrue(capitalizes(.sentences, "(Really?) "))
        XCTAssertTrue(capitalizes(.sentences, "It's 'done.' "))
    }

    func testSentencesDoesNotCapitalizeMidSentence() {
        XCTAssertFalse(capitalizes(.sentences, "hello"))
        XCTAssertFalse(capitalizes(.sentences, "hello "), "space after a word is not a sentence end")
        XCTAssertFalse(capitalizes(.sentences, "hello, "), "comma is not a terminator")
        XCTAssertFalse(capitalizes(.sentences, "hello; "))
    }

    func testSentencesDoesNotCapitalizeAfterTerminatorWithoutSpace() {
        XCTAssertFalse(capitalizes(.sentences, "3."), "decimal point mid-number")
        XCTAssertFalse(capitalizes(.sentences, "Done."), "no space typed yet")
        XCTAssertFalse(capitalizes(.sentences, "$5.9"), "digit after the period")
    }

    // MARK: UIKit trait bridging uses raw values that match UITextAutocapitalizationType

    func testPolicyRawValuesMatchUIKitTrait() {
        // UITextAutocapitalizationType: none=0, words=1, sentences=2, allCharacters=3.
        XCTAssertEqual(QwertyAutocapPolicy(rawValue: 0), QwertyAutocapPolicy.none)
        XCTAssertEqual(QwertyAutocapPolicy(rawValue: 1), .words)
        XCTAssertEqual(QwertyAutocapPolicy(rawValue: 2), .sentences)
        XCTAssertEqual(QwertyAutocapPolicy(rawValue: 3), .allCharacters)
        XCTAssertNil(QwertyAutocapPolicy(rawValue: 4))
    }
}
