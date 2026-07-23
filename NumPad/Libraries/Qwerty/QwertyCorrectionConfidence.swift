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

