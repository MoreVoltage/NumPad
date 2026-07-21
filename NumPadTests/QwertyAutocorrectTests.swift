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

    // MARK: correction decision through rerankKnown — frequency refines known guesses,
    // never demotes unknown ones (QwertyPageHost passes guesses through rerankKnown)

    func testDecideReplacesWithFrequencyPreferredKnownGuess() {
        let lexicon = QwertyFrequencyLexicon(
            data: QwertyFrequencyLexicon.encode(rankedWords: ["the", "ten"]))
        let guesses = lexicon.rerankKnown(["ten", "the"])  // both known: frequency flips them
        XCTAssertEqual(decide("teh", guesses: guesses), .replace(with: "the"))
    }

    func testDecideKeepsUnknownFirstGuessAsReplacement() {
        // Out-of-corpus checker pick (proper noun / jargon shape) survives re-ranking and
        // still auto-applies — a frequent-but-wrong in-corpus word must not displace it.
        let lexicon = QwertyFrequencyLexicon(
            data: QwertyFrequencyLexicon.encode(rankedWords: ["field"]))
        let guesses = lexicon.rerankKnown(["fjords", "field"])
        XCTAssertEqual(decide("fjrods", guesses: guesses), .replace(with: "fjords"))
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

    // MARK: ordering through the frequency re-ranker (design doc §1: re-rank, never replace)

    func testSuggestionsPreserveRerankedCompletionOrder() {
        // UITextChecker's completions(forPartialWordRange:) returns alphabetical order;
        // QwertyPageHost passes them through QwertyFrequencyLexicon.rerank first, and
        // suggestions() must preserve that frequency order — not re-sort or shuffle it.
        let lexicon = QwertyFrequencyLexicon(
            data: QwertyFrequencyLexicon.encode(rankedWords: ["hello", "helm", "held"]))
        let reranked = lexicon.rerank(["held", "helm", "hello"])  // alphabetical, as UITextChecker returns
        let out = QwertyAutocorrect.suggestions(word: "hel", guesses: [], completions: reranked)
        XCTAssertEqual(out, [.literal("hel"), .candidate("hello"), .candidate("helm")])
    }

    func testSuggestionsPreserveRerankedGuessOrder() {
        // Same pipeline for guesses: the highest-frequency guess must land in the middle
        // (auto-apply) slot once the host re-ranks before calling suggestions().
        let lexicon = QwertyFrequencyLexicon(
            data: QwertyFrequencyLexicon.encode(rankedWords: ["the", "ten", "tech"]))
        let reranked = lexicon.rerank(["tech", "ten", "the"])
        let out = QwertyAutocorrect.suggestions(word: "teh", guesses: reranked, completions: [])
        XCTAssertEqual(out, [.literal("teh"), .candidate("the"), .candidate("ten")])
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

    // MARK: personal dictionary — learned words are never auto-corrected (design §2)

    func testUserKnownWordIsNeverAutoCorrected() {
        XCTAssertEqual(QwertyAutocorrect.decide(word: "numpad",
                                                isMisspelled: true,
                                                guesses: ["numbed"],
                                                userRejected: [],
                                                isUserKnownWord: true),
                       .keep,
                       "a word the user accepted repeatedly must never be 'corrected' away")
    }

    func testUnknownWordStillCorrectsThroughTheDefaultParameter() {
        // Existing call sites/tests omit the parameter — behavior must be unchanged.
        XCTAssertEqual(QwertyAutocorrect.decide(word: "teh",
                                                isMisspelled: true,
                                                guesses: ["the"],
                                                userRejected: []),
                       .replace(with: "the"))
    }

    // MARK: personal-first candidate ranking (applied AFTER the frequency re-rank,
    // at the suggestions call sites — the literal-first/dedupe contract of suggestions()
    // itself is untouched)

    func testRankCandidatesMovesPersonalWordsFirst() {
        let boosts = ["numpad": 5]
        let out = QwertyAutocorrect.rankCandidates(["number", "numpad", "numb"],
                                                   personalBoost: { boosts[$0] ?? 0 })
        XCTAssertEqual(out, ["numpad", "number", "numb"])
    }

    func testRankCandidatesHigherBoostWinsAndZeroBoostKeepsOrder() {
        let boosts = ["fjord": 2, "fjords": 7]
        let out = QwertyAutocorrect.rankCandidates(["field", "fjord", "fjords", "fold"],
                                                   personalBoost: { boosts[$0] ?? 0 })
        XCTAssertEqual(out, ["fjords", "fjord", "field", "fold"],
                       "boosted words sort by boost; the frequency-ranked rest keeps its order")
    }

    func testRankCandidatesIsStableForEqualBoosts() {
        let boosts = ["alpha": 3, "beta": 3]
        let out = QwertyAutocorrect.rankCandidates(["beta", "alpha", "gamma"],
                                                   personalBoost: { boosts[$0] ?? 0 })
        XCTAssertEqual(out, ["beta", "alpha", "gamma"],
                       "equal boosts preserve the incoming (frequency-ranked) order")
    }

    func testRankCandidatesOnEmptyInput() {
        XCTAssertEqual(QwertyAutocorrect.rankCandidates([], personalBoost: { _ in 9 }), [])
    }

    // MARK: spatial re-rank feeding decide (the host pipes guesses through
    // QwertySpatialScore.rerank FIRST, so the spatially plausible guess wins the
    // auto-apply slot)

    func testSpatialRerankFeedsDecide() {
        let guesses = QwertySpatialScore.rerank(word: "hrllo", guesses: ["hallo", "hello"])
        let decision = QwertyAutocorrect.decide(word: "hrllo", isMisspelled: true,
                                                guesses: guesses, userRejected: [])
        XCTAssertEqual(decision, .replace(with: "hello"))
    }
}
