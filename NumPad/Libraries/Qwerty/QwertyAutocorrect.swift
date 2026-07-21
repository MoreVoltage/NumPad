import Foundation

/// The pure decision core of the free-floor autocorrect engine (plan §2, Option C):
/// `UITextChecker` supplies misspelling verdicts/guesses/completions at the edge; everything
/// that decides what to *do* with them lives here, fully unit-tested.
enum QwertyAutocorrect {

    enum Decision: Equatable {
        case keep
        case replace(with: String)
    }

    /// One suggestion-bar slot: the literal typed word (always first, system-style quoted
    /// slot) or a replacement candidate.
    enum Suggestion: Equatable {
        case literal(String)
        case candidate(String)
    }

    /// Characters that can appear inside a word (contractions, hyphenated compounds).
    private static let wordInternal: Set<Character> = ["'", "\u{2019}", "-"]

    /// True when the inserted text ends the current word — a space, newline, or punctuation
    /// insertion (every character must be a boundary, so ". " from double-space qualifies).
    static func isBoundary(_ text: String) -> Bool {
        guard !text.isEmpty else { return false }
        return text.allSatisfy { character in
            if character.isLetter || character.isNumber { return false }
            if wordInternal.contains(character) { return false }
            return true
        }
    }

    /// The word immediately before the caret, or nil when the context ends at a boundary.
    static func currentWord(before context: String?) -> String? {
        guard let context = context, !context.isEmpty else { return nil }
        var word = Substring("")
        for character in context.reversed() {
            if character.isLetter || character.isNumber || wordInternal.contains(character) {
                word = Substring(String(character)) + word
            } else {
                break
            }
        }
        return word.isEmpty ? nil : String(word)
    }

    /// Whether to auto-replace `word` at a boundary. Conservative by design — a wrong
    /// correction is worse than a missed one (plan risk #1).
    static func decide(word: String,
                       isMisspelled: Bool,
                       guesses: [String],
                       userRejected: Set<String>,
                       isUserKnownWord: Bool = false) -> Decision {
        guard word.count >= 2 else { return .keep }                    // single letters: autocap's job
        guard !word.contains(where: { $0.isNumber }) else { return .keep }
        guard word != word.uppercased() else { return .keep }           // acronyms
        guard !userRejected.contains(word.lowercased()) else { return .keep }
        guard !isUserKnownWord else { return .keep }                    // learned words (design §2)
        guard isMisspelled, let guess = guesses.first else { return .keep }
        guard guess.lowercased() != word.lowercased() else { return .keep }  // case-only diff: keep the user's casing
        return .replace(with: matchCase(of: word, to: guess))
    }

    /// Personal-first ordering for an already frequency-ranked candidate list (design §2):
    /// higher personal boost first, zero-boost items keep their incoming order. Applied by
    /// the host at the `suggestions` call sites — never inside `suggestions` itself, whose
    /// literal-first/dedupe contract stays untouched.
    static func rankCandidates(_ candidates: [String],
                               personalBoost: (String) -> Int) -> [String] {
        // Explicitly stable: Swift's sort() does not guarantee stability, so tie-break on
        // the incoming index — zero-boost (and equal-boost) items keep their order.
        candidates.enumerated()
            .map { (index: $0.offset, candidate: $0.element, boost: personalBoost($0.element)) }
            .sorted { lhs, rhs in
                guard lhs.boost != rhs.boost else { return lhs.index < rhs.index }
                return lhs.boost > rhs.boost
            }
            .map { $0.candidate }
    }

    /// System-style bar: the literal typed word first, then up to two candidates (guesses
    /// beat completions), deduplicated case-insensitively against the word and each other.
    static func suggestions(word: String,
                            guesses: [String],
                            completions: [String]) -> [Suggestion] {
        guard !word.isEmpty else { return [] }
        var seen: Set<String> = [word.lowercased()]
        var candidates: [String] = []
        for candidate in guesses + completions {
            let key = candidate.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            candidates.append(candidate)
            if candidates.count == 2 { break }
        }
        return [.literal(word)] + candidates.map { .candidate($0) }
    }

    /// Supplementary-lexicon (contacts + Text Replacement) expansion for a finished word.
    /// Case-insensitive on the shortcut; expansion wins over spell correction at a boundary.
    /// `lexicon` keys must be lowercased (see `QwertySpellChecker`).
    static func lexiconExpansion(word: String, lexicon: [String: String]) -> String? {
        guard !word.isEmpty else { return nil }
        return lexicon[word.lowercased()]
    }

    /// Preserves the user's leading capital when applying a correction ("Teh" → "The").
    static func matchCase(of source: String, to candidate: String) -> String {
        guard let first = source.first, first.isUppercase,
              !source.dropFirst().contains(where: { $0.isUppercase }) else { return candidate }
        return candidate.prefix(1).uppercased() + candidate.dropFirst()
    }
}

/// Remembers the most recent applied correction so a backspace immediately after it reverts
/// to the original word — and remembers reverted words so they are never re-corrected in
/// this session (system parity).
struct QwertyAutocorrectHistory {
    struct Revert: Equatable {
        /// `deleteBackward()` calls that remove the corrected word (after the boundary
        /// character has already been deleted by the backspace itself).
        let deletions: Int
        /// The original word to restore.
        let insertion: String
        /// The corrected word as inserted — the caller validates the document context still
        /// ends with this (plus a boundary) before applying, in case the host app moved the
        /// caret since the correction.
        let corrected: String
    }

    private var pending: (original: String, corrected: String)?
    private(set) var rejectedWords: Set<String> = []

    mutating func recordCorrection(original: String, corrected: String) {
        pending = (original, corrected)
    }

    /// Any edit other than the immediately-following backspace invalidates the revert.
    mutating func noteOtherEdit() {
        pending = nil
    }

    /// The user explicitly accepted a word as typed (the quoted literal slot) — never
    /// auto-correct it again this session.
    mutating func reject(_ word: String) {
        rejectedWords.insert(word.lowercased())
    }

    mutating func consumeRevert() -> Revert? {
        guard let correction = pending else { return nil }
        pending = nil
        rejectedWords.insert(correction.original.lowercased())
        return Revert(deletions: correction.corrected.count,
                      insertion: correction.original,
                      corrected: correction.corrected)
    }
}
