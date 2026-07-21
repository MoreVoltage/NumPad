//
//  QwertySymSpellCorrectorTests.swift
//  NumPadTests
//
//  Unit tests for the symmetric-delete correction engine (Task 7 harness arm).
//  Every test runs against a small fixture lexicon built through the SAME
//  `QwertyFrequencyLexicon.encode(rankedWords:)` path production uses, so the
//  corrector is exercised over the real packed-blob reader, not a mock.
//

import XCTest
@testable import NumPad

final class QwertySymSpellCorrectorTests: XCTestCase {

    // MARK: - Fixtures

    /// Packs `rankedWords` (most frequent first) into a real lexicon blob.
    private func fixtureLexicon(_ rankedWords: [String]) -> QwertyFrequencyLexicon {
        QwertyFrequencyLexicon(data: QwertyFrequencyLexicon.encode(rankedWords: rankedWords))
    }

    private func corrector(_ rankedWords: [String]) -> QwertySymSpellCorrector {
        QwertySymSpellCorrector(lexicon: fixtureLexicon(rankedWords))
    }

    // MARK: - Edit-distance-1 recovery (one test per error type)

    func testEdOneSubstitutionFound() {
        let sut = corrector(["hello"])
        XCTAssertEqual(sut.corrections(for: "hellp").first, "hello")
    }

    func testEdOneDeletionFound() {
        // User dropped a character: typed is one SHORTER than intended.
        let sut = corrector(["hello"])
        XCTAssertEqual(sut.corrections(for: "helo").first, "hello")
    }

    func testEdOneInsertionFound() {
        // User fat-fingered an extra character: typed is one LONGER.
        let sut = corrector(["hello"])
        XCTAssertEqual(sut.corrections(for: "heello").first, "hello")
    }

    func testEdOneTranspositionFound() {
        // Adjacent swap counts as ONE edit (OSA), not two substitutions.
        let sut = corrector(["hello"])
        XCTAssertEqual(sut.corrections(for: "hlelo").first, "hello")
    }

    // MARK: - Edit-distance-2 recovery

    func testEdTwoSubstitutionFound() {
        let sut = corrector(["hello"])
        XCTAssertEqual(sut.corrections(for: "hallp").first, "hello")
    }

    func testEdTwoDeletionFound() {
        let sut = corrector(["hello"])
        XCTAssertEqual(sut.corrections(for: "heo").first, "hello")
    }

    func testEdTwoInsertionFound() {
        let sut = corrector(["hello"])
        XCTAssertEqual(sut.corrections(for: "heelloo").first, "hello")
    }

    func testEdTwoDoubleTranspositionFound() {
        // Two independent adjacent swaps = OSA distance 2.
        let sut = corrector(["hello"])
        XCTAssertEqual(sut.corrections(for: "ehlol").first, "hello")
    }

    // MARK: - Ranking: edit distance ASC, then lexicon rank ASC

    func testDistanceBeatsFrequencyThenFrequencyBreaksDistanceTies() {
        // "batch" is the MOST frequent (rank 0) but sits at distance 2 from the
        // query; "bat" (rank 1) and "bath" (rank 2) tie at distance 1, so
        // frequency breaks that tie — the deliberate-tie fixture.
        let sut = corrector(["batch", "bat", "bath"])
        XCTAssertEqual(sut.corrections(for: "batx"), ["bat", "bath", "batch"])
    }

    func testPureDistanceTieResolvedByLexiconRankOrder() {
        // All three candidates are distance 1 — order must be exactly the
        // fixture's frequency order.
        let sut = corrector(["cat", "car", "cab"])
        XCTAssertEqual(sut.corrections(for: "caz"), ["cat", "car", "cab"])
    }

    func testExactLexiconWordReturnsItselfFirst() {
        // Distance 0 outranks every distance-1 neighbor.
        let sut = corrector(["cat", "car", "cab"])
        XCTAssertEqual(sut.corrections(for: "cat").first, "cat")
    }

    // MARK: - Input hygiene

    func testUnknownGarbageReturnsEmpty() {
        let sut = corrector(["hello", "world"])
        XCTAssertEqual(sut.corrections(for: "zzqqzz"), [])
    }

    func testEmptyInputIsSafeAndEmpty() {
        let sut = corrector(["hello"])
        XCTAssertEqual(sut.corrections(for: ""), [])
    }

    func testSingleCharacterInputIsSafe() {
        let sut = corrector(["at"])
        XCTAssertEqual(sut.corrections(for: "a"), ["at"])
    }

    func testWordsLongerThan24CharactersReturnEmpty() {
        let long = String(repeating: "a", count: 25)
        let sut = corrector(["hello", String(repeating: "a", count: 24)])
        XCTAssertEqual(sut.corrections(for: long), [])
    }

    func testUppercaseInputIsLowercasedInAndOut() {
        let sut = corrector(["hello"])
        XCTAssertEqual(sut.corrections(for: "HELLP"), ["hello"])
    }

    func testMaxParameterCapsResultCount() {
        let sut = corrector(["cat", "car", "cab", "can", "cap"])
        XCTAssertEqual(sut.corrections(for: "caz", max: 2), ["cat", "car"])
    }

    // MARK: - Prefix indexing

    func testWordsDifferingBeyondThePrefixWindowAreStillFound() {
        // Default prefixLength is 7: "keyboards" and "keyboardz" share the
        // whole indexed prefix ("keyboar") and differ only at index 8 — the
        // full-string verification must still surface the match.
        let sut = corrector(["keyboards"])
        XCTAssertEqual(sut.corrections(for: "keyboardz").first, "keyboards")
    }

    // MARK: - Determinism

    func testSameFixtureYieldsIdenticalCorrectionsAcrossInstances() {
        let rankedWords = ["hello", "help", "hell", "held", "helm", "shell", "jello"]
        let queries = ["helo", "hellp", "hlelo", "shel", "jelo", "zzz"]
        let first = corrector(rankedWords)
        let second = corrector(rankedWords)
        for query in queries {
            XCTAssertEqual(first.corrections(for: query),
                           second.corrections(for: query),
                           "non-deterministic corrections for \(query)")
        }
    }

    // MARK: - Index introspection (harness support)

    func testPrepareIndexReportsStatsAndIsIdempotent() {
        let sut = corrector(["hello", "world"])
        let first = sut.prepareIndex()
        XCTAssertEqual(first.wordCount, 2)
        XCTAssertGreaterThan(first.variantKeyCount, 0)
        XCTAssertGreaterThanOrEqual(first.postingCount, first.wordCount)
        XCTAssertGreaterThan(first.keyByteCount, 0)
        XCTAssertGreaterThanOrEqual(first.buildMilliseconds, 0)

        // Second call must NOT rebuild: identical counts, same build stamp.
        let second = sut.prepareIndex()
        XCTAssertEqual(second.variantKeyCount, first.variantKeyCount)
        XCTAssertEqual(second.postingCount, first.postingCount)
        XCTAssertEqual(second.buildMilliseconds, first.buildMilliseconds)
    }

    func testEmptyLexiconYieldsEmptyCorrectionsAndZeroStats() {
        let sut = QwertySymSpellCorrector(lexicon: QwertyFrequencyLexicon(data: Data()))
        XCTAssertEqual(sut.corrections(for: "hello"), [])
        XCTAssertEqual(sut.prepareIndex().wordCount, 0)
    }
}
