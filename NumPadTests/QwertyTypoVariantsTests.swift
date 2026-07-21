import XCTest
@testable import NumPad

final class QwertyTypoVariantsTests: XCTestCase {

    private let dictionary: Set<String> = ["accommodate", "hello", "the", "about", "cat"]
    private func isReal(_ w: String) -> Bool { dictionary.contains(w) }

    func testMissingDoubledLetterIsRepaired() {
        XCTAssertEqual(QwertyTypoVariants.repair(word: "accomodate", isRealWord: isReal),
                       "accommodate")
    }

    func testExtraTripledLetterIsCollapsed() {
        XCTAssertEqual(QwertyTypoVariants.repair(word: "helllo", isRealWord: isReal), "hello")
    }

    func testExtraDoubledLetterIsCollapsed() {
        XCTAssertEqual(QwertyTypoVariants.repair(word: "aabout", isRealWord: isReal), "about")
    }

    func testNoValidVariantReturnsNil() {
        XCTAssertNil(QwertyTypoVariants.repair(word: "xyzzy", isRealWord: isReal))
        XCTAssertNil(QwertyTypoVariants.repair(word: "teh", isRealWord: isReal)) // transposition ≠ doubling
    }

    func testSingleMissingLetterOfDoubleIsRepaired() {
        // "helo" → doubling 'l' gives "hello"
        XCTAssertEqual(QwertyTypoVariants.repair(word: "helo", isRealWord: isReal), "hello")
    }

    func testCasePreservedForLeadingCapital() {
        XCTAssertEqual(QwertyTypoVariants.repair(word: "Helllo", isRealWord: isReal), "Hello")
    }

    func testAllCapsShapePreservedThroughRepair() {
        XCTAssertEqual(QwertyTypoVariants.repair(word: "HELLLO", isRealWord: isReal), "HELLO")
    }

    func testAugmentPutsRepairFirstWithoutDuplicating() {
        let out = QwertyTypoVariants.augment(guesses: ["held", "hello"],
                                             word: "helllo", isRealWord: isReal)
        XCTAssertEqual(out, ["hello", "held"])   // promoted, not duplicated
        let out2 = QwertyTypoVariants.augment(guesses: ["held"],
                                              word: "helllo", isRealWord: isReal)
        XCTAssertEqual(out2, ["hello", "held"])  // inserted when absent
        let out3 = QwertyTypoVariants.augment(guesses: ["held"],
                                              word: "teh", isRealWord: isReal)
        XCTAssertEqual(out3, ["held"])           // no repair → unchanged
        let out4 = QwertyTypoVariants.augment(guesses: [],
                                              word: "accomodate", isRealWord: isReal)
        XCTAssertEqual(out4, ["accommodate"])    // empty guess list still gains the repair
    }

    func testOverLengthAndDegenerateInputsAreSafe() {
        let long = String(repeating: "ab", count: 20)   // 40 chars > cap
        XCTAssertNil(QwertyTypoVariants.repair(word: long, isRealWord: isReal))
        XCTAssertNil(QwertyTypoVariants.repair(word: "", isRealWord: isReal))
        XCTAssertNil(QwertyTypoVariants.repair(word: "a", isRealWord: isReal))
    }
}
