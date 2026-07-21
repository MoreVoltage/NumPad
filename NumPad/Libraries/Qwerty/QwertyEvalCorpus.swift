//
//  QwertyEvalCorpus.swift
//  NumPad
//
//  Eval-only corpus of (typed, intended) word pairs for the offline typing-eval
//  harness: a TSV fixture loader plus a seeded, QWERTY-adjacency-weighted
//  synthetic typo generator.
//
//  TARGET NOTE: compiled into the NumPad app target ONLY — deliberately NOT the
//  Keyboard extension (the usual both-targets pattern). Eval code has no runtime
//  purpose on the keyboard and must not bloat the memory-capped extension binary.
//  Tests reach it via `@testable import NumPad`.
//

import Foundation

/// A reproducible set of `(typed, intended)` word pairs for offline evaluation.
///
/// Two sources feed it: committed TSV fixtures (`tools/data/eval/typos_en.tsv`,
/// bundled into the test target) and `synthesizeTypos(words:perWord:seed:)`, a
/// seeded generator that fabricates realistic slips by making ONE adjacency-
/// weighted edit per variant. Determinism is the contract throughout — the
/// generator uses a local SplitMix64 PRNG, never the system RNG, so a given
/// `(words, perWord, seed)` triple always yields byte-identical output.
struct QwertyEvalCorpus {

    /// One eval case: what the user physically typed vs. what they meant.
    /// `Hashable` so harnesses can dedupe and set-diff pairs directly.
    struct Pair: Hashable {
        let typed: String
        let intended: String
    }

    let pairs: [Pair]

    // MARK: - Loading

    /// Parses `typed<TAB>intended` lines. Malformed lines (no tab, or more than
    /// two fields — empty subsequences are kept, so a doubled or trailing tab
    /// counts as an extra field) and blank lines are dropped. Lines split on any
    /// newline CHARACTER (`isNewline`, not `"\n"` — Swift folds CRLF into one
    /// grapheme cluster that a plain `"\n"` split never matches). Each field is
    /// then trimmed of surrounding whitespace/newlines (stray trailing spaces,
    /// lone carriage returns) and lowercased; a field that trims to empty drops
    /// its pair — corrupted fixture lines must never silently poison the corpus.
    init(tsv: String) {
        self.pairs = tsv.split(whereSeparator: \.isNewline).compactMap { line in
            let fields = line.split(separator: "\t", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            guard fields.count == 2, !fields[0].isEmpty, !fields[1].isEmpty else { return nil }
            return Pair(typed: fields[0].lowercased(), intended: fields[1].lowercased())
        }
    }

    /// Loads `<name>.tsv` from `bundle`; nil when the resource is missing or unreadable.
    init?(bundledTSV name: String, bundle: Bundle) {
        guard let url = bundle.url(forResource: name, withExtension: "tsv"),
              let contents = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        self.init(tsv: contents)
    }

    /// Loads `<name>.txt` from `bundle` as one sentence per line, dropping empty
    /// lines. Missing/unreadable resources return `[]` — callers assert on count.
    static func sentences(bundledResource name: String, bundle: Bundle) -> [String] {
        guard let url = bundle.url(forResource: name, withExtension: "txt"),
              let contents = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return contents.split(separator: "\n").map(String.init)
    }

    // MARK: - Synthetic generation

    /// Portion of edits that are substitutions, in parts per thousand; the rest
    /// splits into transposition (150), deletion (125), and insertion (125).
    private static let substitutionShare = 600
    private static let transpositionShare = 150
    private static let deletionShare = 125

    /// Within a substitution, odds (in parts per hundred) that the replacement is
    /// one of the true key's physically adjacent keys rather than any other letter.
    private static let adjacentReplacementShare = 85

    /// Bounded retry count when an edit lands back on the original word (e.g.
    /// transposing "ll") — after this many failed rolls the variant is skipped,
    /// never looped forever.
    private static let maxEditAttempts = 8

    private static let letters = Array("abcdefghijklmnopqrstuvwxyz")

    /// Adjacency lists derived once from `QwertyKeyGeometry` — the same physical
    /// model the scorer uses, so generated slips match what the eval measures.
    private static let adjacentKeys: [Character: [Character]] = {
        var map: [Character: [Character]] = [:]
        for letter in letters {
            map[letter] = letters.filter { QwertyKeyGeometry.areAdjacent(letter, $0) }
        }
        return map
    }()

    /// `perWord` single-edit typo variants of each word, in input order, fully
    /// determined by `seed`. Edits: substitution (60%, replacement 85% adjacency-
    /// weighted), transposition (15%), deletion (12.5%), insertion (12.5%, the
    /// inserted key adjacent to one of its word neighbors). Words too short for
    /// an edit type fall through to substitution. Every emitted pair satisfies
    /// `typed != intended`; a variant that cannot achieve that within the retry
    /// bound is skipped. All output is lowercase.
    static func synthesizeTypos(words: [String], perWord: Int, seed: UInt64) -> [Pair] {
        var rng = SplitMix64(seed: seed)
        var pairs: [Pair] = []
        for word in words {
            let intended = word.lowercased()
            let characters = Array(intended)
            guard !characters.isEmpty else { continue }
            for _ in 0..<perWord {
                for _ in 0..<maxEditAttempts {
                    let typed = applyRandomEdit(to: characters, using: &rng)
                    guard typed != intended else { continue }
                    pairs.append(Pair(typed: typed, intended: intended))
                    break
                }
            }
        }
        return pairs
    }

    // MARK: - Single edits

    private static func applyRandomEdit(
        to characters: [Character], using rng: inout SplitMix64) -> String {
        let roll = rng.below(1000)
        if roll < substitutionShare {
            return substitute(in: characters, using: &rng)
        }
        if roll < substitutionShare + transpositionShare {
            guard characters.count >= 2 else { return substitute(in: characters, using: &rng) }
            return transpose(in: characters, using: &rng)
        }
        if roll < substitutionShare + transpositionShare + deletionShare {
            guard characters.count >= 2 else { return substitute(in: characters, using: &rng) }
            return delete(in: characters, using: &rng)
        }
        return insert(in: characters, using: &rng)
    }

    /// Replaces one random position: 85% with a key adjacent to the true key,
    /// 15% with any other letter. Non-letter positions (no adjacency data) fall
    /// back to the any-other-letter branch, so the result always differs there.
    private static func substitute(
        in characters: [Character], using rng: inout SplitMix64) -> String {
        let position = rng.below(characters.count)
        let original = characters[position]
        let neighbors = adjacentKeys[original] ?? []
        let replacement: Character
        if !neighbors.isEmpty, rng.below(100) < adjacentReplacementShare {
            replacement = neighbors[rng.below(neighbors.count)]
        } else {
            let others = letters.filter { $0 != original }
            replacement = others[rng.below(others.count)]
        }
        var edited = characters
        edited[position] = replacement
        return String(edited)
    }

    /// Swaps a random adjacent index pair. Swapping equal characters returns the
    /// original word — the caller's retry loop handles that.
    private static func transpose(
        in characters: [Character], using rng: inout SplitMix64) -> String {
        let index = rng.below(characters.count - 1)
        var edited = characters
        edited.swapAt(index, index + 1)
        return String(edited)
    }

    private static func delete(
        in characters: [Character], using rng: inout SplitMix64) -> String {
        var edited = characters
        edited.remove(at: rng.below(characters.count))
        return String(edited)
    }

    /// Inserts at a random gap a key adjacent to one of the gap's word neighbors
    /// (the fat-finger pattern: the stray touch lands next to a real keystroke).
    /// Neighbors without adjacency data fall back to any letter.
    private static func insert(
        in characters: [Character], using rng: inout SplitMix64) -> String {
        let gap = rng.below(characters.count + 1)
        var neighborPool: [Character] = []
        if gap > 0 { neighborPool.append(characters[gap - 1]) }
        if gap < characters.count { neighborPool.append(characters[gap]) }
        let anchor = neighborPool[rng.below(neighborPool.count)]
        let candidates = adjacentKeys[anchor] ?? []
        let inserted = candidates.isEmpty
            ? letters[rng.below(letters.count)]
            : candidates[rng.below(candidates.count)]
        var edited = characters
        edited.insert(inserted, at: gap)
        return String(edited)
    }
}

// MARK: - Seeded PRNG

extension QwertyEvalCorpus {

    /// SplitMix64 (Steele/Lea/Flood) — tiny, statistically solid, and above all
    /// SEEDED: the whole point is byte-identical output for a given seed, which
    /// `SystemRandomNumberGenerator` can never provide. All draws go through
    /// `below(_:)` so no Swift-stdlib sampling algorithm sits between the seed
    /// and the output. Deliberately NOT `RandomNumberGenerator`: conforming
    /// would invite exactly the stdlib sampling (`shuffled(using:)`,
    /// `randomElement(using:)`) whose algorithms are not pinned across Swift
    /// versions — the stability contract lives in `next()`/`below(_:)` alone.
    struct SplitMix64 {

        private var state: UInt64

        init(seed: UInt64) {
            self.state = seed
        }

        mutating func next() -> UInt64 {
            state &+= 0x9E3779B97F4A7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return z ^ (z >> 31)
        }

        /// Uniform-ish draw in `0..<bound` via modulo — the tiny modulo bias is
        /// irrelevant for typo fabrication, and the arithmetic is self-contained
        /// so regeneration is stable across Swift versions.
        mutating func below(_ bound: Int) -> Int {
            precondition(bound > 0, "below(_:) needs a positive bound")
            return Int(next() % UInt64(bound))
        }
    }
}
