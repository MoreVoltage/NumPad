import XCTest
@testable import NumPad

final class QwertyCorrectionConfidenceTests: XCTestCase {
    func test_exactKeepSuggestOnlyForShortWords() {
        let features = QwertyCorrectionConfidence.Features(
            typedLength: 2, editDistance: 1, firstCheckerIndex: 0,
            candidateFrequencyRank: 1, runnerUpFrequencyRank: 100, isPersonalCandidate: false)
        XCTAssertEqual(QwertyCorrectionConfidence.decide(features), .suggestOnly)
    }

    func test_editDistanceOneHighFrequencyAutoApplies() {
        let features = QwertyCorrectionConfidence.Features(
            typedLength: 3, editDistance: 1, firstCheckerIndex: 0,
            candidateFrequencyRank: 10, runnerUpFrequencyRank: 100, isPersonalCandidate: false)
        XCTAssertEqual(QwertyCorrectionConfidence.decide(features), .autoApply)
    }

    func test_ambiguousRunnerUpSuggestOnly() {
        let features = QwertyCorrectionConfidence.Features(
            typedLength: 4, editDistance: 1, firstCheckerIndex: 0,
            candidateFrequencyRank: 10, runnerUpFrequencyRank: 12, isPersonalCandidate: false)
        XCTAssertEqual(QwertyCorrectionConfidence.decide(features), .suggestOnly)
    }

    func test_editDistance() {
        XCTAssertEqual(QwertyCorrectionConfidence.editDistance("teh", "the"), 1)
        XCTAssertEqual(QwertyCorrectionConfidence.editDistance("the", "the"), 0)
    }
}

