//
//  QwertyConfidenceGateSweepTests.swift
//  NumPadTests
//
//  The normal suite characterizes the metrics harness deterministically. The expensive
//  release gate is opt-in and fails honestly while any frozen threshold is missed.
//

import XCTest
@testable import NumPad

final class QwertyConfidenceGateSweepTests: XCTestCase {
    private let thresholds = QwertyCorrectionGateThresholds(
        minimumPrecision: 0.95,
        minimumCoverage: 0.35,
        minimumTopThreeRate: 0.917,
        maximumP95Milliseconds: 16.0
    )

    private final class FixtureChecker: QwertyCorrectionSpellChecking {
        func analyze(word: String) -> QwertySpellAnalysis {
            switch word {
            case "teh":
                return QwertySpellAnalysis(isMisspelled: true,
                                           guesses: ["the", "ten"],
                                           completions: [])
            case "helllo":
                return QwertySpellAnalysis(isMisspelled: true,
                                           guesses: ["hellion"],
                                           completions: [])
            default:
                return QwertySpellAnalysis(isMisspelled: false,
                                           guesses: [],
                                           completions: [])
            }
        }

        func isMisspelled(word: String) -> Bool {
            !["the", "hello", "hellion"].contains(word.lowercased())
        }
    }

    func test_metricsCharacterizationUsesFullEvaluatorAndInjectedClock() {
        let lexicon = QwertyFrequencyLexicon(
            data: QwertyFrequencyLexicon.encode(
                rankedWords: ["the", "hello", "alpha", "beta", "gamma", "delta", "ten", "hellion"]))
        let evaluator = QwertyProductionCorrectionEvaluator(
            checker: FixtureChecker(),
            frequencyLexicon: lexicon
        )
        let examples = [
            QwertyCorrectionExample(typed: "helllo", intended: "hello"),
            QwertyCorrectionExample(typed: "teh", intended: "the"),
            QwertyCorrectionExample(typed: "word", intended: "word")
        ]
        var tick: UInt64 = 0

        let metrics = QwertyCorrectionConfidenceHarness.measure(
            examples: examples,
            evaluator: evaluator,
            nowNanoseconds: {
                defer { tick += 1_000_000 }
                return tick
            }
        )

        XCTAssertEqual(metrics.exampleCount, 3)
        XCTAssertEqual(metrics.autoApplyCount, 1)
        XCTAssertEqual(metrics.autoApplyCorrectCount, 1)
        XCTAssertEqual(metrics.precision, 1.0)
        XCTAssertEqual(metrics.coverage, 1.0 / 3.0, accuracy: 0.000_001)
        XCTAssertEqual(metrics.topThreeRate, 2.0 / 3.0, accuracy: 0.000_001)
        XCTAssertEqual(metrics.p95Milliseconds, 1.0)
    }

    func test_releaseConfidenceGate() throws {
        guard ProcessInfo.processInfo.environment["RUN_AUTOCORRECT_CONFIDENCE_GATE"] == "1" else {
            throw XCTSkip("Set RUN_AUTOCORRECT_CONFIDENCE_GATE=1 to run the expensive release gate")
        }
        let bundle = Bundle(for: QwertyEvalCorpusTests.self)
        guard let corpus = QwertyEvalCorpus(bundledTSV: "typos_wiki_en", bundle: bundle) else {
            XCTFail("Wiki corpus fixture missing; the release gate cannot be evaluated")
            return
        }
        let evaluator = QwertyProductionCorrectionEvaluator(
            checker: QwertySystemSpellChecker(),
            frequencyLexicon: QwertyFrequencyLexicon(bundled: bundle)
        )
        let examples = corpus.pairs.map {
            QwertyCorrectionExample(typed: $0.typed, intended: $0.intended)
        }
        let metrics = QwertyCorrectionConfidenceHarness.measure(
            examples: examples,
            evaluator: evaluator,
            nowNanoseconds: { DispatchTime.now().uptimeNanoseconds }
        )

        print(metrics.releaseReport(thresholds: thresholds))
        XCTAssertTrue(metrics.meets(thresholds),
                      "Release gate failed: \(metrics.failures(against: thresholds).joined(separator: ", "))")
    }

    func test_autocorrectDefaultRemainsOffUntilReleaseGatePasses() {
        let suite = "qwerty-confidence-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        XCTAssertFalse(defaults.bool(forKey: Constants.qwertyAutocorrectEnabled.rawValue))
    }
}
