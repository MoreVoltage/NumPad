//
//  QwertySpatialScoreTests.swift
//  NumPadTests
//
//  Tests for the geometry-weighted edit-distance scorer: substitution cost scales
//  with physical key distance; re-ranking is stable and never invents candidates.
//

import XCTest
@testable import NumPad

final class QwertySpatialScoreTests: XCTestCase {

    func testAdjacentSubstitutionCostsLessThanDistant() {
        let near = QwertySpatialScore.editCost(typed: "hrllo", candidate: "hello") // r→e adjacent
        let far  = QwertySpatialScore.editCost(typed: "hrllo", candidate: "hallo") // r→a distant
        XCTAssertLessThan(near, far)
    }

    func testTranspositionIsSingleFlatCost() {
        let cost = QwertySpatialScore.editCost(typed: "teh", candidate: "the")
        XCTAssertEqual(cost, QwertySpatialScore.transpositionCost, accuracy: 0.001)
    }

    func testInsertionAndDeletionAreFlatCost() {
        XCTAssertEqual(QwertySpatialScore.editCost(typed: "helo", candidate: "hello"),
                       QwertySpatialScore.insertDeleteCost, accuracy: 0.001)
        XCTAssertEqual(QwertySpatialScore.editCost(typed: "helllo", candidate: "hello"),
                       QwertySpatialScore.insertDeleteCost, accuracy: 0.001)
    }

    func testIdenticalWordsCostZero() {
        XCTAssertEqual(QwertySpatialScore.editCost(typed: "hello", candidate: "hello"), 0)
    }

    func testRerankPrefersSpatiallyPlausibleGuess() {
        let out = QwertySpatialScore.rerank(word: "hrllo", guesses: ["hallo", "hello"])
        XCTAssertEqual(out, ["hello", "hallo"])
    }

    func testRerankIsStableForEqualCosts() {
        // Two candidates the same distance away keep the checker's order.
        let out = QwertySpatialScore.rerank(word: "cst", guesses: ["cast", "cost"])
        XCTAssertEqual(out, ["cast", "cost"])
    }

    func testRerankToleratesNonLetterAndCaseInput() {
        XCTAssertEqual(QwertySpatialScore.rerank(word: "Hrllo", guesses: ["Hello"]), ["Hello"])
        XCTAssertEqual(QwertySpatialScore.rerank(word: "it's", guesses: ["its"]), ["its"])
        XCTAssertEqual(QwertySpatialScore.rerank(word: "", guesses: ["a"]), ["a"])
    }

    func testRerankSkipsOverLengthWord() {
        // 25 chars — over the cap. If the DP ran, "hello" (adjacent r→e) would jump
        // ahead of "hallo"; the guard must return the incoming order untouched.
        let word = "hrllo" + String(repeating: "x", count: 20)
        XCTAssertEqual(QwertySpatialScore.rerank(word: word, guesses: ["hallo", "hello"]),
                       ["hallo", "hello"])
    }

    func testOverLengthGuessKeepsItsPosition() {
        // The unscorable 25-char guess holds slot 0 while the scored guesses re-order
        // among themselves in the remaining slots (rerankKnown-style slot preservation;
        // sort-last would produce ["hello", "hallo", long] instead).
        let long = String(repeating: "a", count: 25)
        let out = QwertySpatialScore.rerank(word: "hrllo", guesses: [long, "hallo", "hello"])
        XCTAssertEqual(out, [long, "hello", "hallo"])
    }

    func testSubstitutionCostIsCappedForMaxDistanceKeys() {
        // q→p is 9 key-pitches apart: 0.4 + 0.3 × 9 = 3.1, capped at 1.3 (still under
        // the 2.0 a delete + insert pair would cost, so the DP takes the substitution).
        XCTAssertEqual(QwertySpatialScore.editCost(typed: "qat", candidate: "pat"),
                       1.3, accuracy: 0.001)
    }

    func testNonLetterSubstitutionUsesFlatCost() {
        // '1' has no key geometry, so 1→l takes the flat unit cost, not a spatial one.
        XCTAssertEqual(QwertySpatialScore.editCost(typed: "he1lo", candidate: "hello"),
                       1.0, accuracy: 0.001)
    }

    func testSpatialThenRerankKnownComposition() {
        // The spatial-then-frequency composition (formerly production; now the eval
        // harness's `spatial`/`variantsLast` arm shape — the spatial resort left the
        // production path per the 2026-07-21 eval-baseline Task 6b arbitration). The
        // lexicon knows hullo (rank 0) and hallo (rank 1); "hello" is out-of-corpus.
        let lexicon = QwertyFrequencyLexicon(
            data: QwertyFrequencyLexicon.encode(rankedWords: ["hullo", "hallo"]))
        let out = lexicon.rerankKnown(
            QwertySpatialScore.rerank(word: "hrllo", guesses: ["hallo", "hullo", "hello"]))
        // Spatial orders by cost: hello 0.7 (r→e), hallo ~1.21 (r→a), hullo 1.3 (r→u) —
        // out-of-corpus "hello" lands in slot 0 and STAYS there (rerankKnown never moves
        // unknown words); frequency then flips the two known words (hullo outranks
        // hallo) within the slots the known words occupied.
        XCTAssertEqual(out, ["hello", "hullo", "hallo"])
    }
}
