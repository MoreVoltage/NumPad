import Foundation

/// The per-user learned-word store behind NumPad Type's autocorrect protection and
/// personal-first suggestion ranking (design doc
/// docs/plans/full-keyboard/2026-07-12-glide-and-accuracy-design.md §2). Pure value type —
/// storage, recording triggers, and ranking application live at the edge (`QwertyPageHost`).
///
/// PRIVACY (design §2): contents never leave the app group — no SettingsSync broadcast on
/// writes, no analytics reads, no export path. The container app only ever *clears* it
/// (Reset Typing Personalization in the NumPad Type wizard).
struct QwertyPersonalDictionary: Codable, Equatable {

    private(set) var counts: [String: Int] = [:]
    private(set) var recordingsSinceDecay = 0

    static let capacity = 1_500
    /// Recordings between halvings. Tuned (review follow-up) so protection survives normal
    /// typing volume: every accepted word advances this clock, and at ~40wpm a 200-word
    /// window meant everything halved every ~5 minutes — a name accepted 3× lost isKnown
    /// protection almost immediately. Decay exists to age out one-off noise and bound the
    /// table, not to fight learning; 2,000 recordings is a heavy day of typing.
    static let decayInterval = 2_000
    /// Count at which a word is "known": protected from autocorrect.
    static let protectionThreshold = 3

    // MARK: - Recording

    /// Counts one acceptance of `word` (lowercased, curly apostrophe folded to straight).
    /// Junk never counts: only letters plus in-word '/- allowed, length 2–24, at least one
    /// letter. Returns whether the word was recorded, so callers can skip persisting
    /// hygiene-rejected input.
    ///
    /// Decay runs BEFORE the incoming word is recorded: a first-seen word landing exactly
    /// on the interval boundary survives at count 1 instead of being recorded and then
    /// immediately halved to zero and dropped.
    @discardableResult
    mutating func recordAcceptance(of word: String) -> Bool {
        guard let normalized = Self.normalize(word) else { return false }
        recordingsSinceDecay += 1
        if recordingsSinceDecay >= Self.decayInterval {
            decay()
        }
        if counts[normalized] == nil, counts.count >= Self.capacity {
            evictLowestCountEntry()
        }
        counts[normalized, default: 0] += 1
        return true
    }


    /// Removes a learned word (case-insensitive). Returns whether an entry existed.
    @discardableResult
    mutating func remove(_ word: String) -> Bool {
        let key = Self.fold(word)
        return counts.removeValue(forKey: key) != nil
    }

    /// Explicitly adds/boosts a word from the personal-dictionary UI. Same hygiene as acceptance.
    @discardableResult
    mutating func addExplicit(_ word: String) -> Bool {
        recordAcceptance(of: word)
    }

    // MARK: - Lookup

    /// The learned count for `word` (case-insensitive, apostrophes folded); 0 when absent.
    func boost(for word: String) -> Int {
        counts[Self.fold(word)] ?? 0
    }

    /// A word the user has accepted at least `protectionThreshold` times — never auto-correct.
    func isKnown(_ word: String) -> Bool {
        boost(for: word) >= Self.protectionThreshold
    }

    // MARK: - Hygiene

    /// Words age out unless re-typed: every `decayInterval` recordings all counts halve and
    /// zeros drop, so one-off acceptances never accumulate forever.
    private mutating func decay() {
        counts = counts.compactMapValues { count in
            let halved = count / 2
            return halved > 0 ? halved : nil
        }
        recordingsSinceDecay = 0
    }

    /// Deterministic eviction at capacity: lowest count first, ties broken alphabetically.
    private mutating func evictLowestCountEntry() {
        guard let victim = counts.min(by: { ($0.value, $0.key) < ($1.value, $1.key) }) else {
            return
        }
        counts.removeValue(forKey: victim.key)
    }

    /// Lowercases and folds the curly apostrophe (\u{2019}, smart punctuation) to the
    /// straight one, so both variants of a contraction accumulate — and look up — as ONE
    /// entry. Shared by the recording and lookup paths.
    private static func fold(_ word: String) -> String {
        word.lowercased().replacingOccurrences(of: "\u{2019}", with: "'")
    }

    /// Folded; letters plus in-word '/- only; length 2–24; at least one letter (pure
    /// punctuation is junk). Mirrors QwertyAutocorrect's word-internal character set.
    private static func normalize(_ word: String) -> String? {
        let normalized = fold(word)
        guard (2...24).contains(normalized.count) else { return nil }
        guard normalized.contains(where: { $0.isLetter }) else { return nil }
        let wordInternal: Set<Character> = ["'", "-"]
        guard normalized.allSatisfy({ $0.isLetter || wordInternal.contains($0) }) else {
            return nil
        }
        return normalized
    }
}

// MARK: - Persistence coding (raw-Data app-group key: UserPrefs.qwertyPersonalDictionaryData)

extension QwertyPersonalDictionary {
    /// Decodes a stored dictionary; empty or corrupt data degrades to an empty dictionary
    /// (the QwertyFrequencyLexicon resilience posture — never crash the keyboard).
    init(data: Data) {
        guard !data.isEmpty,
              let decoded = try? JSONDecoder().decode(QwertyPersonalDictionary.self, from: data)
        else {
            self = QwertyPersonalDictionary()
            return
        }
        self = decoded
    }

    /// JSON blob for the app-group store (≤ `capacity` short entries — cheap to encode on
    /// every mutation at typing speed).
    func encoded() -> Data {
        (try? JSONEncoder().encode(self)) ?? Data()
    }
}
