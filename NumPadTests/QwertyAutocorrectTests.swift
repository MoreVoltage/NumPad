import XCTest
@testable import NumPad

final class QwertyAutocorrectTests: XCTestCase {

    private final class FixtureSpellChecker: QwertyCorrectionSpellChecking {
        let analyses: [String: QwertySpellAnalysis]
        let realWords: Set<String>

        init(analyses: [String: QwertySpellAnalysis], realWords: Set<String>) {
            self.analyses = analyses
            self.realWords = realWords
        }

        func analyze(word: String) -> QwertySpellAnalysis {
            analyses[word] ?? QwertySpellAnalysis(isMisspelled: false,
                                                  guesses: [],
                                                  completions: [])
        }

        func isMisspelled(word: String) -> Bool {
            !realWords.contains(word.lowercased())
        }
    }

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
        XCTAssertEqual(items, [.literal("the"), .candidate("then"), .empty],
                       "candidates equal to the typed word add nothing")
    }

    func testNoWordMeansNoSuggestions() {
        XCTAssertEqual(QwertyAutocorrect.suggestions(word: "", guesses: ["a"], completions: []), [.empty, .empty, .empty])
    }

    func testSuggestionBarStateAlwaysProducesThreeTypedSlots() {
        let state = QwertySuggestionBarState.suggestions([
            .literal("teh"),
            .candidate("the")
        ])

        XCTAssertEqual(state.slots, [
            .suggestion(.literal("teh")),
            .suggestion(.candidate("the")),
            .empty
        ])
        XCTAssertEqual(state.slots.count, 3)
    }

    func testCorrectedStateIncludesMarkerAndLiteralUndoChip() {
        let state = QwertySuggestionBarState.corrected(original: "teh", replacement: "the")

        XCTAssertEqual(state.slots, [
            .corrected(original: "teh", replacement: "the"),
            .undoLiteral("teh"),
            .empty
        ])
        XCTAssertEqual(state.slots.count, 3)
    }

    func testSuggestionImpressionCountsOnlyWhenCandidateStateChanges() {
        let first = QwertySuggestionBarState.suggestions([
            .literal("te"), .candidate("ten"), .empty
        ])
        let same = QwertySuggestionBarState.suggestions([
            .literal("te"), .candidate("ten"), .empty
        ])
        let next = QwertySuggestionBarState.suggestions([
            .literal("teh"), .candidate("the"), .empty
        ])

        XCTAssertFalse(same.isNewCandidateImpression(comparedTo: first))
        XCTAssertTrue(next.isNewCandidateImpression(comparedTo: first))
        XCTAssertFalse(QwertySuggestionBarState.corrected(
            original: "teh", replacement: "the"
        ).isNewCandidateImpression(comparedTo: next))
    }

    func testProductionEvaluatorRunsCheckerRankingVariantRepairAndConfidencePolicy() {
        let checker = FixtureSpellChecker(
            analyses: [
                "helllo": QwertySpellAnalysis(isMisspelled: true,
                                               guesses: ["hellion"],
                                               completions: [])
            ],
            realWords: ["hello", "hellion"]
        )
        let lexicon = QwertyFrequencyLexicon(
            data: QwertyFrequencyLexicon.encode(rankedWords: ["hello", "hellion"]))
        let evaluator = QwertyProductionCorrectionEvaluator(
            checker: checker,
            frequencyLexicon: lexicon
        )

        let evaluation = evaluator.evaluate(word: "helllo")

        XCTAssertEqual(evaluation.rankedGuesses.first, "hello",
                       "the live typo-variant candidate generator must run in the evidence path")
        XCTAssertEqual(evaluation.applyPolicy, .suggestOnly(candidate: "hello"),
                       "an oracle repair absent from the checker head must not bypass confidence")
        XCTAssertEqual(evaluation.suggestionSlots, [
            .literal("helllo"), .candidate("hello"), .candidate("hellion")
        ])
    }

    func testProductionEvaluatorHonorsSessionRejectionAtApplyBoundary() {
        let checker = FixtureSpellChecker(
            analyses: [
                "teh": QwertySpellAnalysis(isMisspelled: true,
                                            guesses: ["the"],
                                            completions: [])
            ],
            realWords: ["the"]
        )
        let evaluator = QwertyProductionCorrectionEvaluator(
            checker: checker,
            frequencyLexicon: QwertyFrequencyLexicon(
                data: QwertyFrequencyLexicon.encode(rankedWords: ["the"]))
        )

        let evaluation = evaluator.evaluate(word: "teh", userRejected: ["teh"])

        XCTAssertEqual(evaluation.applyPolicy, .keep)
        XCTAssertEqual(evaluation.rankedGuesses, ["the"],
                       "candidate generation still runs; only application is rejected")
    }

    func testColdCacheBoundaryWithAutocorrectDoesNotLearnUnevaluatedWord() {
        var seededDictionary = QwertyPersonalDictionary()
        seededDictionary.recordAcceptance(of: "anchor")
        var actualDictionary = seededDictionary

        let action = QwertyBoundaryCorrection.resolve(
            evaluation: nil,
            recordAcceptance: { actualDictionary.recordAcceptance(of: "teh") })

        XCTAssertEqual(action, .preserveTypedText)
        XCTAssertEqual(actualDictionary, seededDictionary,
                       "a cold cache must not change counts or advance the decay clock")
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
        let revert = history.consumeRevert(matching: { _ in true })
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
        _ = history.consumeRevert(matching: { _ in true })
        XCTAssertNil(history.consumeRevert(matching: { _ in true }))
    }

    func testAnyOtherKeyInvalidatesTheRevert() {
        var history = QwertyAutocorrectHistory()
        history.recordCorrection(original: "teh", corrected: "the")
        history.noteOtherEdit()
        XCTAssertNil(history.consumeRevert(matching: { _ in true }),
                     "revert only applies to a backspace immediately after the correction")
    }

    func testRevertedWordIsRemembered() {
        var history = QwertyAutocorrectHistory()
        history.recordCorrection(original: "teh", corrected: "the")
        _ = history.consumeRevert(matching: { _ in true })
        XCTAssertTrue(history.rejectedWords.contains("teh"))
    }

    func testStaleContextDoesNotConsumeOrRejectCorrection() {
        var history = QwertyAutocorrectHistory()
        history.recordCorrection(original: "teh", corrected: "the")

        XCTAssertNil(history.consumeRevert(matching: { _ in false }))
        XCTAssertNotNil(history.peekRevert(),
                        "context validation must happen before history mutation")
        XCTAssertFalse(history.rejectedWords.contains("teh"),
                       "a failed stale-context check is not a user rejection")
    }

    func testPageSwitchEndsImmediateCorrectionScope() {
        var history = QwertyAutocorrectHistory()
        history.recordCorrection(original: "teh", corrected: "the")

        history.endImmediateCorrectionScope()  // QWERTY -> numpad

        XCTAssertNil(history.peekRevert())
        XCTAssertFalse(history.rejectedWords.contains("teh"))
    }

    func testDeactivateThenReactivateStartsWithoutStaleCorrection() {
        var history = QwertyAutocorrectHistory()
        history.recordCorrection(original: "teh", corrected: "the")

        history.endImmediateCorrectionScope()  // deactivate
        history.endImmediateCorrectionScope()  // activate is idempotently clean

        XCTAssertNil(history.peekRevert())
        history.recordCorrection(original: "adn", corrected: "and")
        XCTAssertEqual(history.peekRevert()?.corrected, "and",
                       "a reactivated session can establish a fresh correction")
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

    // MARK: spatial re-rank feeding decide — a QwertySpatialScore MODULE test, not a
    // production-pipeline test: the spatial resort left the production guess path per
    // the eval-baseline arbitration (docs/plans/full-keyboard/research/
    // 2026-07-21-eval-baseline.md, Task 6b addendum). This documents module behavior:
    // rerank's output order is decide-compatible and the spatially plausible guess
    // sorts first.

    func testSpatialRerankFeedsDecide() {
        let guesses = QwertySpatialScore.rerank(word: "hrllo", guesses: ["hallo", "hello"])
        let decision = QwertyAutocorrect.decide(word: "hrllo", isMisspelled: true,
                                                guesses: guesses, userRejected: [])
        XCTAssertEqual(decision, .replace(with: "hello"))
    }

    // MARK: composed pipeline — frequency → typo-variant augment → decide
    // (the exact QwertyPageHost.rankedGuesses shape after the Task-6b rewire)

    func testTypoRepairAugmentFeedsDecideWhenCheckerHasNoGuesses() {
        // "accomodate" is the checker's classic miss: misspelled, zero guesses. The
        // doubling repair becomes the ONLY candidate and wins the auto-apply slot.
        let dictionary: Set<String> = ["accommodate"]
        let lexicon = QwertyFrequencyLexicon(
            data: QwertyFrequencyLexicon.encode(rankedWords: ["accommodate"]))
        let guesses = QwertyTypoVariants.augment(
            guesses: lexicon.rerankKnown([]),
            word: "accomodate",
            isRealWord: { dictionary.contains($0) })
        let decision = QwertyAutocorrect.decide(word: "accomodate", isMisspelled: true,
                                                guesses: guesses, userRejected: [])
        XCTAssertEqual(decision, .replace(with: "accommodate"))
    }

    func testTypoRepairTakesHeadOverAdjacentRivalInComposedPipeline() {
        // PINS THE ARBITRATED BEHAVIOR. The eval baseline (docs/plans/full-keyboard/
        // research/2026-07-21-eval-baseline.md, Task 6b addendum) measured augment-last
        // WITHOUT the spatial resort (`noSpatialAugmentLast`, wiki top-1 82.0%) as the
        // best pipeline, and production was rewired to it. Hand-computed under the new
        // ordering:
        //   frequency: rerankKnown(["help"]) → ["help"] (single known guess)
        //   augment:   repair("helo") → "hello" (doubling variant) prepended
        //              → ["hello", "help"]
        // The checker-validated doubling repair takes the head unconditionally — and
        // therefore the auto-apply slot — over the adjacent-key rival "help" that the
        // retired spatial resort used to promote.
        let dictionary: Set<String> = ["hello", "help"]
        let lexicon = QwertyFrequencyLexicon(
            data: QwertyFrequencyLexicon.encode(rankedWords: ["help", "hello"]))
        let guesses = QwertyTypoVariants.augment(
            guesses: lexicon.rerankKnown(["help"]),
            word: "helo",
            isRealWord: { dictionary.contains($0) })
        let decision = QwertyAutocorrect.decide(word: "helo", isMisspelled: true,
                                                guesses: guesses, userRejected: [])
        XCTAssertEqual(decision, .replace(with: "hello"))
    }

    // MARK: suggestion coordination — latency / duplicate-work contract

    func testSuggestionRequestUsesACompactRejectedWordsGeneration() {
        let before = QwertySuggestionRequest(
            word: "hello",
            lexiconGeneration: 1,
            personalizationGeneration: 1,
            rejectedWordsGeneration: 4)
        let after = QwertySuggestionRequest(
            word: "hello",
            lexiconGeneration: 1,
            personalizationGeneration: 1,
            rejectedWordsGeneration: 5)

        XCTAssertNotEqual(before, after)
    }

    @MainActor
    func testSuggestionCoordinatorCoalescesAnExactPendingRequest() {
        var scheduled: [@MainActor () -> Void] = []
        let coordinator = QwertySuggestionCoordinator<Int>(
            capacity: 2,
            schedule: { scheduled.append($0) })
        let request = QwertySuggestionRequest(
            word: "hello",
            lexiconGeneration: 1,
            personalizationGeneration: 2,
            rejectedWordsGeneration: 0)
        var evaluationCount = 0
        var applied: [Int] = []

        coordinator.request(
            request,
            input: 20,
            evaluate: { input in
                evaluationCount += 1
                return input + 1
            },
            apply: { _, value in
                applied.append(value)
                return true
            })
        coordinator.request(
            request,
            input: 20,
            evaluate: { input in
                evaluationCount += 1
                return input + 1
            },
            apply: { _, value in
                applied.append(value)
                return true
            })

        XCTAssertEqual(scheduled.count, 1)
        scheduled.removeFirst()()
        XCTAssertEqual(evaluationCount, 1)
        XCTAssertEqual(applied, [21])
        XCTAssertEqual(coordinator.metrics.requests, 2)
        XCTAssertEqual(coordinator.metrics.coalesces, 1)
        XCTAssertEqual(coordinator.metrics.evaluations, 1)
        XCTAssertEqual(coordinator.metrics.resultApplies, 1)
    }

    @MainActor
    func testSuggestionCoordinatorSupersedesPendingWorkBeforeCheckerEvaluation() {
        var scheduled: [@MainActor () -> Void] = []
        let coordinator = QwertySuggestionCoordinator<String>(
            capacity: 2,
            schedule: { scheduled.append($0) })
        let first = QwertySuggestionRequest(
            word: "hel",
            lexiconGeneration: 1,
            personalizationGeneration: 1,
            rejectedWordsGeneration: 0)
        let latest = QwertySuggestionRequest(
            word: "hell",
            lexiconGeneration: 1,
            personalizationGeneration: 1,
            rejectedWordsGeneration: 0)
        var evaluated: [String] = []
        var applied: [String] = []

        for request in [first, latest] {
            coordinator.request(
                request,
                input: request.word,
                evaluate: { input in
                    evaluated.append(input)
                    return input.uppercased()
                },
                apply: { request, value in
                    applied.append("\(request.word):\(value)")
                    return true
                })
        }

        XCTAssertEqual(scheduled.count, 2)
        scheduled.removeFirst()()
        scheduled.removeFirst()()
        XCTAssertEqual(evaluated, ["hell"])
        XCTAssertEqual(applied, ["hell:HELL"])
        XCTAssertEqual(coordinator.metrics.staleDiscards, 1)
        XCTAssertEqual(coordinator.metrics.evaluations, 1)
    }

    @MainActor
    func testSuggestionCoordinatorUsesBoundedCacheAndExplicitInvalidation() {
        var scheduled: [@MainActor () -> Void] = []
        let coordinator = QwertySuggestionCoordinator<Int>(
            capacity: 2,
            schedule: { scheduled.append($0) })
        let request = QwertySuggestionRequest(
            word: "hello",
            lexiconGeneration: 1,
            personalizationGeneration: 1,
            rejectedWordsGeneration: 0)
        var evaluationCount = 0
        var applied: [Int] = []

        func submit() {
            coordinator.request(
                request,
                input: 7,
                evaluate: { input in
                    evaluationCount += 1
                    return input
                },
                apply: { _, value in
                    applied.append(value)
                    return true
                })
        }

        submit()
        scheduled.removeFirst()()
        submit()
        XCTAssertTrue(scheduled.isEmpty, "a warm exact result must apply without new checker work")
        XCTAssertEqual(evaluationCount, 1)
        XCTAssertEqual(coordinator.metrics.cacheHits, 1)
        XCTAssertEqual(applied, [7, 7])

        coordinator.invalidate()
        submit()
        XCTAssertEqual(scheduled.count, 1)
        scheduled.removeFirst()()
        XCTAssertEqual(evaluationCount, 2)
    }

    @MainActor
    func testSuggestionCoordinatorEvictsTheLeastRecentlyUsedEntryAtCapacity() {
        var scheduled: [@MainActor () -> Void] = []
        let coordinator = QwertySuggestionCoordinator<Int>(
            capacity: 2,
            schedule: { scheduled.append($0) })
        let requests = (0..<3).map { generation in
            QwertySuggestionRequest(
                word: "word\(generation)",
                lexiconGeneration: UInt64(generation),
                personalizationGeneration: 0,
                rejectedWordsGeneration: 0)
        }

        for (value, request) in requests.enumerated() {
            coordinator.request(
                request,
                input: value,
                evaluate: { $0 },
                apply: { _, _ in true })
            scheduled.removeFirst()()
        }

        XCTAssertNil(coordinator.cachedResult(for: requests[0]))
        XCTAssertEqual(coordinator.cachedResult(for: requests[1]), 1)
        XCTAssertEqual(coordinator.cachedResult(for: requests[2]), 2)
    }

    @MainActor
    func testSuggestionCoordinatorCountsAVisibleWordMismatchAsStaleNotApplied() {
        var scheduled: [@MainActor () -> Void] = []
        let coordinator = QwertySuggestionCoordinator<Int>(
            schedule: { scheduled.append($0) })
        let request = QwertySuggestionRequest(
            word: "hello",
            lexiconGeneration: 1,
            personalizationGeneration: 1,
            rejectedWordsGeneration: 0)

        coordinator.request(
            request,
            input: 1,
            evaluate: { $0 },
            apply: { _, _ in false })
        scheduled.removeFirst()()

        XCTAssertEqual(coordinator.metrics.staleDiscards, 1)
        XCTAssertEqual(coordinator.metrics.resultApplies, 0)
    }
}
