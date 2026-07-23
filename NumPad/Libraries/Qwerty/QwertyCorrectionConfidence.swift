import Foundation

enum QwertyCorrectionConfidence {
    struct Features: Equatable {
        let typedLength: Int
        let editDistance: Int
        let firstCheckerIndex: Int
        let candidateFrequencyRank: Int?
        let runnerUpFrequencyRank: Int?
        let isPersonalCandidate: Bool
    }

    enum Decision: Equatable {
        case suggestOnly
        case autoApply
    }

    /// Conservative measured policy: edit-distance ≤1, typed length ≥3, checker head, and
    /// a clear frequency margin when ranks are known. Designed to prioritize precision.
    static func decide(_ features: Features) -> Decision {
        guard features.typedLength >= 3 else { return .suggestOnly }
        guard features.editDistance == 1 else { return .suggestOnly }
        guard features.firstCheckerIndex == 0 else { return .suggestOnly }
        guard !features.isPersonalCandidate else { return .autoApply }
        if let rank = features.candidateFrequencyRank {
            if let runner = features.runnerUpFrequencyRank, runner - rank < 5 {
                return .suggestOnly
            }
            guard rank <= 5000 else { return .suggestOnly }
        }
        return .autoApply
    }

    /// Restricted Damerau-Levenshtein (single transposition of adjacent characters).
    static func editDistance(_ a: String, _ b: String) -> Int {
        let aChars = Array(a.lowercased())
        let bChars = Array(b.lowercased())
        let n = aChars.count
        let m = bChars.count
        if n == 0 { return m }
        if m == 0 { return n }
        var dp = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)
        for i in 0...n { dp[i][0] = i }
        for j in 0...m { dp[0][j] = j }
        for i in 1...n {
            for j in 1...m {
                let cost = aChars[i - 1] == bChars[j - 1] ? 0 : 1
                dp[i][j] = min(dp[i - 1][j] + 1, dp[i][j - 1] + 1, dp[i - 1][j - 1] + cost)
                if i > 1, j > 1,
                   aChars[i - 1] == bChars[j - 2],
                   aChars[i - 2] == bChars[j - 1] {
                    dp[i][j] = min(dp[i][j], dp[i - 2][j - 2] + cost)
                }
            }
        }
        return dp[n][m]
    }
}

struct QwertyCorrectionExample: Equatable {
    let typed: String
    let intended: String
}

struct QwertyCorrectionGateThresholds: Equatable {
    let minimumPrecision: Double
    let minimumCoverage: Double
    let minimumTopThreeRate: Double
    let maximumP95Milliseconds: Double
}

struct QwertyCorrectionMetrics: Equatable {
    let exampleCount: Int
    let autoApplyCount: Int
    let autoApplyCorrectCount: Int
    let topThreeHitCount: Int
    let precision: Double
    let coverage: Double
    let topThreeRate: Double
    let p95Milliseconds: Double

    func failures(against thresholds: QwertyCorrectionGateThresholds) -> [String] {
        var failures: [String] = []
        if precision < thresholds.minimumPrecision {
            failures.append("precision \(formatted(precision)) < \(formatted(thresholds.minimumPrecision))")
        }
        if coverage < thresholds.minimumCoverage {
            failures.append("coverage \(formatted(coverage)) < \(formatted(thresholds.minimumCoverage))")
        }
        if topThreeRate < thresholds.minimumTopThreeRate {
            failures.append("top-3 \(formatted(topThreeRate)) < \(formatted(thresholds.minimumTopThreeRate))")
        }
        if p95Milliseconds >= thresholds.maximumP95Milliseconds {
            failures.append("p95 \(formatted(p95Milliseconds))ms >= \(formatted(thresholds.maximumP95Milliseconds))ms")
        }
        return failures
    }

    func meets(_ thresholds: QwertyCorrectionGateThresholds) -> Bool {
        failures(against: thresholds).isEmpty
    }

    func releaseReport(thresholds: QwertyCorrectionGateThresholds) -> String {
        """
        QWERTY autocorrect confidence metrics
        examples=\(exampleCount)
        precision=\(formatted(precision))
        coverage=\(formatted(coverage))
        top3=\(formatted(topThreeRate))
        p95_ms=\(formatted(p95Milliseconds))
        auto_apply=\(autoApplyCount)
        auto_apply_correct=\(autoApplyCorrectCount)
        outcome=\(meets(thresholds) ? "PASS" : "FAIL")
        """
    }

    private func formatted(_ value: Double) -> String {
        String(format: "%.4f", value)
    }
}

enum QwertyCorrectionConfidenceHarness {
    /// Measures the entire evaluator call. Examples are sorted so corpus file ordering cannot
    /// change decisions, counts, or the injected-clock latency characterization.
    static func measure(examples: [QwertyCorrectionExample],
                        evaluator: QwertyProductionCorrectionEvaluator,
                        nowNanoseconds: () -> UInt64) -> QwertyCorrectionMetrics {
        let ordered = examples.sorted {
            ($0.typed.lowercased(), $0.intended.lowercased())
                < ($1.typed.lowercased(), $1.intended.lowercased())
        }
        var autoApplyCount = 0
        var autoApplyCorrectCount = 0
        var topThreeHitCount = 0
        var latencies: [UInt64] = []
        latencies.reserveCapacity(ordered.count)

        for example in ordered {
            let start = nowNanoseconds()
            let evaluation = evaluator.evaluate(word: example.typed)
            let end = nowNanoseconds()
            latencies.append(end >= start ? end - start : 0)

            // Product-level top-three: the actual stable bar has three slots, including
            // its literal slot. Count only a visible candidate that can really be tapped.
            if evaluation.suggestionSlots.contains(where: {
                guard case .candidate(let candidate) = $0 else { return false }
                return candidate.caseInsensitiveCompare(example.intended) == .orderedSame
            }) {
                topThreeHitCount += 1
            }
            if case .autoApply(_, let replacement) = evaluation.applyPolicy {
                autoApplyCount += 1
                if replacement.caseInsensitiveCompare(example.intended) == .orderedSame {
                    autoApplyCorrectCount += 1
                }
            }
        }

        let count = ordered.count
        let precision = autoApplyCount == 0
            ? 1
            : Double(autoApplyCorrectCount) / Double(autoApplyCount)
        let coverage = count == 0 ? 0 : Double(autoApplyCount) / Double(count)
        let topThreeRate = count == 0 ? 0 : Double(topThreeHitCount) / Double(count)
        let p95Milliseconds: Double
        if latencies.isEmpty {
            p95Milliseconds = 0
        } else {
            let sorted = latencies.sorted()
            let index = max(0, min(sorted.count - 1,
                                   Int(ceil(Double(sorted.count) * 0.95)) - 1))
            p95Milliseconds = Double(sorted[index]) / 1_000_000
        }
        return QwertyCorrectionMetrics(
            exampleCount: count,
            autoApplyCount: autoApplyCount,
            autoApplyCorrectCount: autoApplyCorrectCount,
            topThreeHitCount: topThreeHitCount,
            precision: precision,
            coverage: coverage,
            topThreeRate: topThreeRate,
            p95Milliseconds: p95Milliseconds)
    }
}
