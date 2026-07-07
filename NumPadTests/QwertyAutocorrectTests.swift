import XCTest
@testable import NumPad

final class QwertyAutocorrectTests: XCTestCase {

    // MARK: word boundaries

    func testBoundaryCharacters() {
        for text in [" ", "\n", ".", ",", "!", "?", ";", ":", ")", "\""] {
            XCTAssertTrue(QwertyAutocorrect.isBoundary(text), "'\(text)' ends a word")
        }
        for text in ["a", "Z", "5", "'", "-"] {
            XCTAssertFalse(QwertyAutocorrect.isBoundary(text),
                           "'\(text)' can appear inside a word (contractions, hyphens)")
        }
    }

    // MARK: current-word extraction from the document context

    func testExtractsTrailingWord() {
        XCTAssertEqual(QwertyAutocorrect.currentWord(before: "hello teh"), "teh")
        XCTAssertEqual(QwertyAutocorrect.currentWord(before: "teh"), "teh")
        XCTAssertEqual(QwertyAutocorrect.currentWord(before: "it's don't"), "don't")
        XCTAssertEqual(QwertyAutocorrect.currentWord(before: "well-known"), "well-known")
    }

    func testNoWordAtBoundaryOrEmpty() {
        XCTAssertNil(QwertyAutocorrect.currentWord(before: "hello "))
        XCTAssertNil(QwertyAutocorrect.currentWord(before: "hello."))
        XCTAssertNil(QwertyAutocorrect.currentWord(before: ""))
        XCTAssertNil(QwertyAutocorrect.currentWord(before: nil))
    }

    // MARK: correction decision — when to auto-replace at a boundary

    private func decide(_ word: String,
                        misspelled: Bool = true,
                        guesses: [String] = ["the"],
                        rejected: Set<String> = []) -> QwertyAutocorrect.Decision {
        QwertyAutocorrect.decide(word: word,
                                 isMisspelled: misspelled,
                                 guesses: guesses,
                                 userRejected: rejected)
    }

    func testMisspelledWordWithGuessIsReplaced() {
        XCTAssertEqual(decide("teh"), .replace(with: "the"))
    }

    func testCorrectlySpelledWordIsKept() {
        XCTAssertEqual(decide("the", misspelled: false), .keep)
    }

    func testNoGuessesKeepsTheWord() {
        XCTAssertEqual(decide("xzqj", guesses: []), .keep)
    }

    func testUserRejectedWordIsNeverReCorrected() {
        XCTAssertEqual(decide("teh", rejected: ["teh"]), .keep,
                       "a reverted correction must not come back (system parity)")
    }

    func testSingleLetterIsNeverCorrected() {
        XCTAssertEqual(decide("i", guesses: ["I"]), .keep,
                       "single letters are too ambiguous — system leaves them to shift/autocap")
    }

    func testAllCapsWordIsNeverCorrected() {
        XCTAssertEqual(decide("TEH", guesses: ["THE"]), .keep,
                       "all-caps reads as an acronym (system parity)")
    }

    func testWordsWithDigitsAreNeverCorrected() {
        XCTAssertEqual(decide("teh1", guesses: ["the"]), .keep)
    }

    func testCapitalizedMisspellingPreservesLeadingCase() {
        XCTAssertEqual(decide("Teh", guesses: ["the"]), .replace(with: "The"),
                       "corrections keep the user's leading capital")
    }

    // MARK: suggestion bar model — system-style three slots

    func testSuggestionsLeadWithLiteralOriginal() {
        let items = QwertyAutocorrect.suggestions(word: "teh",
                                                  guesses: ["the", "ten", "tech"],
                                                  completions: [])
        XCTAssertEqual(items.first, .literal("teh"))
        XCTAssertEqual(items, [.literal("teh"), .candidate("the"), .candidate("ten")])
    }

    func testSuggestionsFallBackToCompletions() {
        let items = QwertyAutocorrect.suggestions(word: "hel",
                                                  guesses: [],
                                                  completions: ["hello", "help", "helm"])
        XCTAssertEqual(items, [.literal("hel"), .candidate("hello"), .candidate("help")])
    }

    func testSuggestionsDedupeCaseInsensitively() {
        let items = QwertyAutocorrect.suggestions(word: "the",
                                                  guesses: ["The"],
                                                  completions: ["the", "then"])
        XCTAssertEqual(items, [.literal("the"), .candidate("then")],
                       "candidates equal to the typed word add nothing")
    }

    func testNoWordMeansNoSuggestions() {
        XCTAssertTrue(QwertyAutocorrect.suggestions(word: "", guesses: ["a"], completions: []).isEmpty)
    }

    // MARK: revert bookkeeping — backspace right after a correction restores the original

    func testRevertRestoresOriginalWord() {
        var history = QwertyAutocorrectHistory()
        history.recordCorrection(original: "teh", corrected: "the")
        let revert = history.consumeRevert()
        XCTAssertEqual(revert?.deletions, 3)
        XCTAssertEqual(revert?.insertion, "teh")
        XCTAssertEqual(revert?.corrected, "the")
    }

    func testExplicitRejectionBlocksCorrection() {
        var history = QwertyAutocorrectHistory()
        history.reject("Teh")
        XCTAssertEqual(QwertyAutocorrect.decide(word: "teh",
                                                isMisspelled: true,
                                                guesses: ["the"],
                                                userRejected: history.rejectedWords),
                       .keep,
                       "tapping the quoted literal accepts the word for the session")
    }

    func testRevertIsSingleUse() {
        var history = QwertyAutocorrectHistory()
        history.recordCorrection(original: "teh", corrected: "the")
        _ = history.consumeRevert()
        XCTAssertNil(history.consumeRevert())
    }

    func testAnyOtherKeyInvalidatesTheRevert() {
        var history = QwertyAutocorrectHistory()
        history.recordCorrection(original: "teh", corrected: "the")
        history.noteOtherEdit()
        XCTAssertNil(history.consumeRevert(),
                     "revert only applies to a backspace immediately after the correction")
    }

    func testRevertedWordIsRemembered() {
        var history = QwertyAutocorrectHistory()
        history.recordCorrection(original: "teh", corrected: "the")
        _ = history.consumeRevert()
        XCTAssertTrue(history.rejectedWords.contains("teh"))
    }

    // MARK: supplementary-lexicon expansion (contacts + Text Replacement shortcuts)

    func testLexiconExpandsExactShortcut() {
        let lexicon = ["omw": "On my way!"]
        XCTAssertEqual(QwertyAutocorrect.lexiconExpansion(word: "omw", lexicon: lexicon),
                       "On my way!")
    }

    func testLexiconMatchesCaseInsensitively() {
        let lexicon = ["omw": "On my way!"]
        XCTAssertEqual(QwertyAutocorrect.lexiconExpansion(word: "OMW", lexicon: lexicon),
                       "On my way!")
    }

    func testLexiconNoMatchReturnsNil() {
        XCTAssertNil(QwertyAutocorrect.lexiconExpansion(word: "brb", lexicon: ["omw": "On my way!"]))
        XCTAssertNil(QwertyAutocorrect.lexiconExpansion(word: "", lexicon: ["omw": "x"]))
    }

    func testLexiconExpansionBeatsSpellCorrection() {
        // Text Replacement wins over autocorrect at a boundary (system parity): the pipeline
        // asks for expansion first; only a nil expansion falls through to decide().
        let lexicon = ["teh": "The Extension Handbook"]
        XCTAssertEqual(QwertyAutocorrect.lexiconExpansion(word: "teh", lexicon: lexicon),
                       "The Extension Handbook")
    }
}
