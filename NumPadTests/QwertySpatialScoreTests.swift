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
}
