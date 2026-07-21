//
//  QwertyTypoVariants.swift
//  NumPad
//
//  Targeted repair of two narrow typo classes `UITextChecker`'s guess list handles
//  poorly: under/over-doubled letters ("acommodate", "helllo") and their inverse.
//

import Foundation

/// Generates doubling-repair variants of a misspelled word and promotes the first one
/// the caller's validity oracle accepts to the head of the guess list.
///
/// **Problem.** The checker's guesses routinely miss doubled-letter slips: "accomodate"
/// often surfaces nothing useful, and "helllo" can rank exotic candidates over the
/// obvious collapse. These are mechanical, enumerable errors — a handful of targeted
/// variants checked against a real-word oracle beats hoping the guess list covers them.
///
/// **Policy (mirrors `QwertySpatialScore`'s).** This module augments GUESSES only; the
/// checker's misspelling verdict is untouched — a word this module can repair is still
/// reported misspelled by the checker, and a word the checker likes never reaches
/// `repair`. Validity is judged by the caller: the host passes a `UITextChecker`-backed
/// closure, tests pass a fixture set — the module itself carries no dictionary.
enum QwertyTypoVariants {

    /// Words shorter than this are never repaired — doubling a single letter is autocap/
    /// fat-finger territory, not a doubling typo.
    static let minRepairableLength = 2

    /// Words longer than this are never repaired (same defensive cap as
    /// `QwertySpatialScore.maxScoredLength` — real corrections are far shorter).
    static let maxRepairableLength = 24

    /// Belt-and-suspenders ceiling on generated variants — and thus `isRealWord` probes —
    /// per call. The length cap above is what actually bounds generation (≤12 collapse +
    /// ≤24 doubling variants for a 24-char word, so ≤36 < 48); this can only bind if that
    /// arithmetic ever drifts. The oracle is `UITextChecker` in production, and probes
    /// run per keystroke while the current word is misspelled.
    static let maxVariants = 48

    /// The best doubling repair of `word`, or nil when no generated variant is a real word.
    ///
    /// Operates on the lowercased word and generates, in order: (a) each run of ≥2
    /// identical letters collapsed by one ("helllo" → "hello", "aabout" → "about"), then
    /// (b) each letter doubled once ("accomodate" → "accommodate"). Collapse comes first —
    /// an over-doubled run is the more distinctive signal. The FIRST variant `isRealWord`
    /// accepts wins, returned with the typed word's leading capital restored via
    /// `QwertyAutocorrect.matchCase(of:to:)`.
    static func repair(word: String, isRealWord: (String) -> Bool) -> String? {
        let characters = Array(word.lowercased())
        guard characters.count >= minRepairableLength,
              characters.count <= maxRepairableLength else { return nil }

        var seen: Set<String> = []
        var variants: [String] = []
        for variant in collapsedRunVariants(of: characters) + doubledLetterVariants(of: characters) {
            guard variants.count < maxVariants else { break }
            guard seen.insert(variant).inserted else { continue }  // "lll" doubles to ONE string
            variants.append(variant)
        }
        guard let match = variants.first(where: isRealWord) else { return nil }
        return QwertyAutocorrect.matchCase(of: word, to: match)
    }

    /// `guesses` with the repair of `word` moved to index 0: an existing case-insensitive
    /// match is promoted (removed, then prepended in the repair's casing); an absent repair
    /// is prepended. A nil repair returns `guesses` unchanged.
    static func augment(guesses: [String], word: String,
                        isRealWord: (String) -> Bool) -> [String] {
        guard let repaired = repair(word: word, isRealWord: isRealWord) else { return guesses }
        let key = repaired.lowercased()
        return [repaired] + guesses.filter { $0.lowercased() != key }
    }

    // MARK: - Variant generation

    /// One variant per run of ≥2 identical letters, with that run shortened by one
    /// character ("helllo" → "hello"). Non-letter runs ("--") are never collapsed.
    private static func collapsedRunVariants(of characters: [Character]) -> [String] {
        var variants: [String] = []
        var index = 0
        while index < characters.count {
            var runEnd = index + 1
            while runEnd < characters.count, characters[runEnd] == characters[index] {
                runEnd += 1
            }
            if runEnd - index >= 2, characters[index].isLetter {
                variants.append(String(characters[..<index] + characters[(index + 1)...]))
            }
            index = runEnd
        }
        return variants
    }

    /// One variant per letter position, with that letter doubled ("helo" → "hhelo",
    /// "heelo", "hello", "heloo"). Non-letters (apostrophes, hyphens) are never doubled.
    private static func doubledLetterVariants(of characters: [Character]) -> [String] {
        characters.indices
            .filter { characters[$0].isLetter }
            .map { String(characters[..<$0] + [characters[$0]] + characters[$0...]) }
    }
}
