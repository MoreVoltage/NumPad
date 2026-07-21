//
//  QwertySpatialScore.swift
//  NumPad
//
//  Geometry-weighted Damerau-Levenshtein scoring of correction guesses: a substitution
//  between physically adjacent keys costs less than one between distant keys, so
//  re-ranking prefers the spatially plausible correction.
//

import Foundation

/// Re-orders `UITextChecker`'s correction guesses by spatial typing plausibility.
///
/// **Problem.** The checker ranks guesses by flat edit likelihood: "hrllo" → "hello"
/// (r sits beside e) and "hrllo" → "hallo" (r is nowhere near a) look equally close,
/// yet the first is overwhelmingly the intended word — fingers miss to NEIGHBORING
/// keys. Because `QwertyAutocorrect.decide()` auto-replaces with `guesses.first`,
/// guess ordering directly decides which word auto-correct picks.
///
/// **Policy (mirrors `QwertyFrequencyLexicon.rerankKnown`'s philosophy).** Spatial
/// score refines ordering among the checker's own guesses; it never invents candidates
/// and never overrides the checker's misspelling verdict. The host runs this pass
/// FIRST — spatial cost fixes gross implausibility, then the frequency/personal passes
/// refine among the plausible.
///
/// **Cost model.** A restricted (OSA) Damerau-Levenshtein distance over lowercased
/// characters: insert/delete/transpose are flat, but substitution scales with the
/// physical distance between the two keys (`QwertyKeyGeometry`), so adjacent-key slips
/// land well under the flat cost while distant substitutions approach
/// `substitutionCostCap`. Per-character key positions are hoisted once per word before
/// the DP, so the O(m×n) inner loop is pure arithmetic. Pure and Foundation-only.
enum QwertySpatialScore {

    /// Flat cost of one insertion or deletion (the classic unit cost).
    static let insertDeleteCost = 1.0

    /// Flat cost of transposing two neighboring characters ("teh" → "the") — slightly
    /// under `insertDeleteCost`: a swap is one physical slip, not two independent edits.
    static let transpositionCost = 0.9

    /// Substitution cost = `min(cap, base + slope × key distance)`: adjacent keys
    /// (distance ≤ `QwertyKeyGeometry.adjacencyThreshold`) land ≈0.7–0.76, distant keys
    /// approach the cap. Identical characters cost 0.
    private static let substitutionCostBase = 0.4
    private static let substitutionCostSlope = 0.3
    private static let substitutionCostCap = 1.3

    /// Substitution cost when either character has no key geometry (apostrophes, digits,
    /// accented letters) — the classic flat unit cost, carrying no spatial signal.
    private static let flatSubstitutionCost = 1.0

    /// Words and candidates longer than this skip the DP entirely (same ceiling the
    /// typing pipeline's word handling assumes; real corrections are far shorter).
    private static let maxScoredLength = 24

    /// Sort key for candidates the DP never scored — larger than any scaled edit cost
    /// (≤ ~62,400 for two max-length words), so unscored candidates sort after every
    /// scored one, ties among them staying stable.
    private static let unscoredSortKey = Double(Int32.max)

    /// Costs are compared rounded to 3 decimals (scaled by this, then `rounded()`) so
    /// float noise can't break the stable incoming-order tie-break.
    private static let costRoundingScale = 1000.0

    // MARK: - Scoring

    /// Geometry-weighted OSA (restricted Damerau-Levenshtein) distance from `typed` to
    /// `candidate`, over lowercased characters. Three-row rolling implementation:
    /// O(m×n) time, O(n) space.
    static func editCost(typed: String, candidate: String) -> Double {
        let source = Array(typed.lowercased())
        let target = Array(candidate.lowercased())
        if source.isEmpty { return Double(target.count) * insertDeleteCost }
        if target.isEmpty { return Double(source.count) * insertDeleteCost }

        // Hoisted once per word — the DP inner loop never touches geometry or casing.
        let sourceCenters = source.map(QwertyKeyGeometry.unitCenter(of:))
        let targetCenters = target.map(QwertyKeyGeometry.unitCenter(of:))

        var previousPrevious = [Double](repeating: 0, count: target.count + 1)
        var previous = (0...target.count).map { Double($0) * insertDeleteCost }
        var current = [Double](repeating: 0, count: target.count + 1)

        for i in 1...source.count {
            current[0] = Double(i) * insertDeleteCost
            for j in 1...target.count {
                let substitution = substitutionCost(source[i - 1], sourceCenters[i - 1],
                                                    target[j - 1], targetCenters[j - 1])
                var best = min(previous[j] + insertDeleteCost,     // delete source[i-1]
                               current[j - 1] + insertDeleteCost,  // insert target[j-1]
                               previous[j - 1] + substitution)     // substitute / match
                if i > 1, j > 1,
                   source[i - 1] == target[j - 2], source[i - 2] == target[j - 1] {
                    best = min(best, previousPrevious[j - 2] + transpositionCost)
                }
                current[j] = best
            }
            (previousPrevious, previous, current) = (previous, current, previousPrevious)
        }
        return previous[target.count]
    }

    /// Stable re-ordering of `guesses` by ascending geometry-weighted edit cost from
    /// `word`; equal (rounded) costs keep the checker's incoming order. Empty `word`,
    /// empty `guesses`, or an over-length `word` return `guesses` unchanged; an
    /// over-length candidate is unscored and sorts after every scored one.
    static func rerank(word: String, guesses: [String]) -> [String] {
        guard !word.isEmpty, !guesses.isEmpty, word.count <= maxScoredLength else {
            return guesses
        }
        return guesses.enumerated()
            .map { (order: $0.offset, guess: $0.element,
                    key: sortKey(word: word, guess: $0.element)) }
            .sorted { ($0.key, $0.order) < ($1.key, $1.order) }
            .map(\.guess)
    }

    // MARK: - Internals

    /// Rounded-and-scaled cost sort key (3-decimal precision), or `unscoredSortKey` for
    /// an over-length candidate.
    private static func sortKey(word: String, guess: String) -> Double {
        guard guess.count <= maxScoredLength else { return unscoredSortKey }
        return (editCost(typed: word, candidate: guess) * costRoundingScale).rounded()
    }

    /// Cost of substituting `b` for `a` given their pre-hoisted key centers: 0 for
    /// identical characters, distance-scaled for two letter keys, flat otherwise.
    private static func substitutionCost(_ a: Character, _ aCenter: (x: Double, y: Double)?,
                                         _ b: Character, _ bCenter: (x: Double, y: Double)?) -> Double {
        if a == b { return 0 }
        guard let aCenter = aCenter, let bCenter = bCenter else { return flatSubstitutionCost }
        let dx = aCenter.x - bCenter.x
        let dy = aCenter.y - bCenter.y
        let distance = (dx * dx + dy * dy).squareRoot()
        return min(substitutionCostCap, substitutionCostBase + substitutionCostSlope * distance)
    }
}
