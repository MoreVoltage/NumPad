//
//  QwertyConfidenceGateSweepTests.swift
//  NumPadTests
//
//  Predeclared confidence threshold sweep against the wiki typo corpus.
//  Gates (design/plan): precision ≥95%, coverage ≥35%, top-3 ≥91.7%, p95 <16ms.
//  Autocorrect remains default-OFF unless a policy clears every gate.
//

import XCTest
@testable import NumPad

final class QwertyConfidenceGateSweepTests: XCTestCase {
    /// Design gates — do not lower after seeing results.
    private let minPrecision = 0.95
    private let minCoverage = 0.35
    private let minTop3 = 0.917
    private let maxP95Ms = 16.0

    func test_confidenceGateSweep_recordsMetricsAndKeepsAutocorrectOff() throws {
        let bundle = Bundle(for: QwertyEvalCorpusTests.self)
        guard let corpus = QwertyEvalCorpus(bundledTSV: "typos_wiki_en", bundle: bundle) else {
            throw XCTSkip("Wiki corpus fixture missing")
        }
        let lexicon = QwertyFrequencyLexicon(bundled: .main)
        let checker = UITextChecker()
        let language = "en_US"

        // Sample for latency; full corpus for accuracy/coverage.
        var autoApplyTotal = 0
        var autoApplyCorrect = 0
        var top3Hits = 0
        var latenciesNs: [UInt64] = []
        let pairs = corpus.pairs

        for (index, pair) in pairs.enumerated() {
            let typed = pair.typed
            let intended = pair.intended
            let range = NSRange(location: 0, length: typed.utf16.count)
            let misspelled = checker.rangeOfMisspelledWord(
                in: typed, range: range, startingAt: 0, wrap: false, language: language
            )
            let guesses: [String]
            if misspelled.location == NSNotFound {
                guesses = []
            } else {
                guesses = checker.guesses(forWordRange: misspelled, in: typed, language: language) ?? []
            }
            let ranked = lexicon.rerankKnown(guesses)
            let top3 = Array(ranked.prefix(3))
            if top3.contains(where: { $0.caseInsensitiveCompare(intended) == .orderedSame }) {
                top3Hits += 1
            }

            guard let head = ranked.first else { continue }
            let checkerIndex = guesses.firstIndex { $0.caseInsensitiveCompare(head) == .orderedSame } ?? Int.max
            let candidateRank = lexicon.rank(of: head)
            let runnerUpRank = ranked.dropFirst().first.flatMap { lexicon.rank(of: $0) }

            let start = DispatchTime.now().uptimeNanoseconds
            let decision = QwertyAutocorrect.autoApplyDecision(
                word: typed,
                candidate: head,
                checkerIndex: checkerIndex,
                candidateFrequencyRank: candidateRank,
                runnerUpFrequencyRank: runnerUpRank,
                isPersonalCandidate: false
            )
            let elapsed = DispatchTime.now().uptimeNanoseconds - start
            if index < 500 { latenciesNs.append(elapsed) }

            if decision == .autoApply {
                autoApplyTotal += 1
                if head.caseInsensitiveCompare(intended) == .orderedSame {
                    autoApplyCorrect += 1
                }
            }
        }

        let precision = autoApplyTotal == 0 ? 1.0 : Double(autoApplyCorrect) / Double(autoApplyTotal)
        let coverage = pairs.isEmpty ? 0.0 : Double(autoApplyTotal) / Double(pairs.count)
        let top3Rate = pairs.isEmpty ? 0.0 : Double(top3Hits) / Double(pairs.count)
        let p95Ms: Double = {
            guard !latenciesNs.isEmpty else { return 0 }
            let sorted = latenciesNs.sorted()
            let idx = min(sorted.count - 1, Int(Double(sorted.count - 1) * 0.95))
            return Double(sorted[idx]) / 1_000_000.0
        }()

        let report = """
        # QWERTY Autocorrect Confidence Gate Sweep
        Date: 2026-07-23
        Corpus: typos_wiki_en (\(pairs.count) pairs)
        Policy: typedLength≥3, editDistance==1, checkerIndex==0, rank≤5000, runner-up margin≥5

        | Metric | Value | Gate | Pass |
        |---|---|---|---|
        | Auto-apply precision | \(String(format: "%.4f", precision)) | ≥ \(minPrecision) | \(precision >= minPrecision) |
        | Auto-apply coverage | \(String(format: "%.4f", coverage)) | ≥ \(minCoverage) | \(coverage >= minCoverage) |
        | Candidate top-3 | \(String(format: "%.4f", top3Rate)) | ≥ \(minTop3) | \(top3Rate >= minTop3) |
        | Decision p95 (ms) | \(String(format: "%.3f", p95Ms)) | < \(maxP95Ms) | \(p95Ms < maxP95Ms) |
        | Auto-apply count | \(autoApplyTotal) | | |
        | Auto-apply correct | \(autoApplyCorrect) | | |

        Gate outcome: \(
            precision >= minPrecision
                && coverage >= minCoverage
                && top3Rate >= minTop3
                && p95Ms < maxP95Ms
            ? "PASS — autocorrect may be enabled by release decision"
            : "FAIL — keep suggestions; autocorrect remains default-OFF"
        )

        Autocorrect UserPrefs default remains false. Thresholds were not lowered.
        """

        let outURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("docs/release/2026-07-23-autocorrect-confidence-gate.md")
        try report.write(to: outURL, atomically: true, encoding: .utf8)

        // Production posture: default-off until every gate passes. Do not flip the default here.
        let gatesPass = precision >= minPrecision
            && coverage >= minCoverage
            && top3Rate >= minTop3
            && p95Ms < maxP95Ms
        if !gatesPass {
            XCTAssertFalse(UserPrefs.qwertyAutocorrect,
                           "Autocorrect must remain off when confidence gates fail")
        }

        // Soft assertion of gate numbers is recorded in the report; failing the suite for a
        // known-failing gate would block unrelated work. The release gate is the report file.
        print(report)
    }
}

