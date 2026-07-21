//
//  QwertySymSpellCorrector.swift
//  NumPad
//
//  HARNESS ARM ONLY (research plan Task 7) — compiled into the NumPad APP
//  target exclusively, like `QwertyEvalCorpus`; deliberately NOT in the
//  Keyboard extension. This engine ships nowhere until/unless it clears the
//  pre-registered adoption gates (+15pp absolute top-1 over the baseline —
//  reported both vs-floor and vs-current-production, ≤15MB resident delta,
//  ≤16ms p95 added latency); Task 9 owns any wiring decision. The ceiling
//  math was known in advance: current production misses only ~14.0pp of
//  lexicon-reachable wiki pairs, so even a PERFECT dictionary corrector
//  cannot clear +15pp vs production — the arm exists to measure the honest
//  number, not to force a pass.
//
//  Clean-room reimplementation of the symmetric-delete spelling-correction
//  algorithm (SymSpell — the ALGORITHM is MIT-published by Wolf Garbe; no
//  third-party code is used or ported here) over OUR packed
//  `QwertyFrequencyLexicon` blob: precompute, for every lexicon word, all
//  delete-variants of its first `prefixLength` characters up to
//  `maxEditDistance` deletions (variant → [lexicon ranks]); at lookup time
//  generate the query's delete-variants the same way, union the candidate
//  ranks, and verify each candidate's TRUE edit distance on the full strings.
//
//  Deliberately geometry-free: verification uses plain unit-cost OSA
//  (optimal string alignment / restricted Damerau-Levenshtein), NOT
//  `QwertySpatialScore`'s geometry-weighted costs — the eval baseline showed
//  the spatial prior is net-negative, and this engine measures the
//  frequency-only hypothesis.
//
//  Pure and Foundation-only. The delete-variant index is built lazily on the
//  first `corrections(for:)` call (via an internal reference-typed cache box —
//  the ONE deliberate exception to the value-semantics rule in this file, so
//  the harness can construct the corrector cheaply and measure the build cost
//  explicitly with `prepareIndex()`).
//

import Foundation

struct QwertySymSpellCorrector {

    // MARK: - Tuning constants

    /// Queries longer than this return no corrections (matches the corpus
    /// reality: no English typo pair is anywhere near this long, and it caps
    /// the OSA verification cost).
    private static let maxQueryLength = 24

    /// Milliseconds per nanosecond divisor for the build-time stamp.
    private static let nanosecondsPerMillisecond = 1_000_000.0

    // MARK: - Index introspection (harness support)

    /// Size/cost facts about the built delete-variant index, for the harness
    /// report's honest memory arithmetic. `buildMilliseconds` is stamped once
    /// at build time and never changes afterwards (idempotence signal).
    struct IndexStats: Equatable {
        /// Lexicon words indexed.
        let wordCount: Int
        /// Unique delete-variant keys in the index.
        let variantKeyCount: Int
        /// Total (variant → rank) postings across all keys.
        let postingCount: Int
        /// Sum of UTF-8 byte lengths of all variant keys.
        let keyByteCount: Int
        /// Wall-clock cost of the one-time index build.
        let buildMilliseconds: Double
    }

    // MARK: - Init

    init(lexicon: QwertyFrequencyLexicon, maxEditDistance: Int = 2, prefixLength: Int = 7) {
        self.lexicon = lexicon
        self.maxEditDistance = maxEditDistance
        self.prefixLength = prefixLength
    }

    private let lexicon: QwertyFrequencyLexicon
    private let maxEditDistance: Int
    private let prefixLength: Int
    private let cache = IndexCache()

    // MARK: - API

    /// Ranked corrections for `word`: symmetric-delete candidate lookup,
    /// full-string OSA verification (distance ≤ `maxEditDistance`), ordered by
    /// (edit distance ASC, lexicon rank ASC), at most `max` words.
    /// Lowercase in/out; empty, over-long, or unknown-garbage input → `[]`.
    func corrections(for word: String, max limit: Int = 5) -> [String] {
        let query = Array(word.lowercased())
        guard limit > 0, !query.isEmpty, query.count <= Self.maxQueryLength else { return [] }
        let index = builtIndex()

        var seenRanks = Set<UInt32>()
        var verified: [(distance: Int, rank: UInt32, word: String)] = []
        for variant in Self.deleteVariants(of: query,
                                           prefixLength: prefixLength,
                                           maxDeletes: maxEditDistance) {
            guard let postings = index.variants[variant] else { continue }
            for rank in postings where seenRanks.insert(rank).inserted {
                guard Int(rank) < index.wordsByRank.count,
                      let candidate = index.wordsByRank[Int(rank)] else { continue }
                let candidateCharacters = Array(candidate)
                // Cheap length screen before the DP: a length gap beyond the
                // edit budget can never verify.
                guard abs(candidateCharacters.count - query.count) <= maxEditDistance else {
                    continue
                }
                let distance = Self.osaDistance(query, candidateCharacters)
                guard distance <= maxEditDistance else { continue }
                verified.append((distance: distance, rank: rank, word: candidate))
            }
        }
        // (distance, rank) is a total order — ranks are unique — so the result
        // is deterministic regardless of Set/Dictionary iteration order.
        return verified
            .sorted { ($0.distance, $0.rank) < ($1.distance, $1.rank) }
            .prefix(limit)
            .map(\.word)
    }

    /// Builds the index if it hasn't been built yet and returns its stats.
    /// Idempotent — a second call returns the cached stats without rebuilding.
    @discardableResult
    func prepareIndex() -> IndexStats {
        builtIndex().stats
    }

    // MARK: - Lazy index

    /// Reference box holding the built index — see the header note on why this
    /// single reference type exists inside a value-semantics module.
    private final class IndexCache {
        var index: Index?
    }

    private struct Index {
        /// delete-variant → lexicon ranks whose word produced that variant.
        let variants: [String: [UInt32]]
        /// rank → word (nil only for rank gaps in a corrupt blob).
        let wordsByRank: [String?]
        let stats: IndexStats
    }

    private func builtIndex() -> Index {
        if let built = cache.index { return built }
        let built = buildIndex()
        cache.index = built
        return built
    }

    private func buildIndex() -> Index {
        let start = DispatchTime.now()
        let entries = lexicon.allEntries()
        let maxRank = entries.map(\.rank).max() ?? -1

        var wordsByRank = [String?](repeating: nil, count: maxRank + 1)
        var variants: [String: [UInt32]] = [:]
        var postingCount = 0
        for entry in entries where entry.rank >= 0 {
            // Blob words are stored lowercased already (encode lowercases).
            wordsByRank[entry.rank] = entry.word
            let rank = UInt32(entry.rank)
            for variant in Self.deleteVariants(of: Array(entry.word),
                                               prefixLength: prefixLength,
                                               maxDeletes: maxEditDistance) {
                variants[variant, default: []].append(rank)
                postingCount += 1
            }
        }

        let keyByteCount = variants.keys.reduce(0) { $0 + $1.utf8.count }
        let elapsedMs = Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds)
            / Self.nanosecondsPerMillisecond
        let stats = IndexStats(wordCount: entries.count,
                               variantKeyCount: variants.count,
                               postingCount: postingCount,
                               keyByteCount: keyByteCount,
                               buildMilliseconds: elapsedMs)
        return Index(variants: variants, wordsByRank: wordsByRank, stats: stats)
    }

    // MARK: - Delete variants

    /// All delete-variants of the first `prefixLength` characters of `word`
    /// with 0...`maxDeletes` deletions — the 0-delete prefix itself included.
    /// Applied identically to lexicon words (index side) and queries (lookup
    /// side); that symmetry is the whole algorithm.
    private static func deleteVariants(of word: [Character],
                                       prefixLength: Int,
                                       maxDeletes: Int) -> Set<String> {
        let prefix = Array(word.prefix(prefixLength))
        var variants: Set<String> = [String(prefix)]
        var frontier: Set<[Character]> = [prefix]
        for _ in 0..<maxDeletes {
            var next: Set<[Character]> = []
            for variant in frontier where !variant.isEmpty {
                for position in variant.indices {
                    var shorter = variant
                    shorter.remove(at: position)
                    next.insert(shorter)
                }
            }
            frontier = next
            for variant in next { variants.insert(String(variant)) }
        }
        return variants
    }

    // MARK: - Verification distance

    /// Plain unit-cost optimal-string-alignment distance (restricted
    /// Damerau-Levenshtein: substitution, insertion, deletion, and adjacent
    /// transposition all cost 1). Deliberately NOT `QwertySpatialScore`'s
    /// geometry-weighted cost — see the header.
    private static func osaDistance(_ a: [Character], _ b: [Character]) -> Int {
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var twoBack = [Int](repeating: 0, count: b.count + 1)
        var previous = Array(0...b.count)
        var current = [Int](repeating: 0, count: b.count + 1)
        for i in 1...a.count {
            current[0] = i
            for j in 1...b.count {
                let substitutionCost = a[i - 1] == b[j - 1] ? 0 : 1
                current[j] = min(previous[j] + 1,          // deletion
                                 current[j - 1] + 1,       // insertion
                                 previous[j - 1] + substitutionCost)
                if i > 1, j > 1, a[i - 1] == b[j - 2], a[i - 2] == b[j - 1] {
                    current[j] = min(current[j], twoBack[j - 2] + 1)  // transposition
                }
            }
            // Roll the rows: twoBack ← previous (row i−1), previous ← current
            // (row i), current ← recycled buffer.
            swap(&twoBack, &previous)
            swap(&previous, &current)
        }
        return previous[b.count]
    }
}
