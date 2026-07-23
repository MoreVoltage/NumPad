import Foundation
import UIKit

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
        /// Placeholder for an unused bar slot — rendered empty and noninteractive.
        case empty
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
    /// correction is worse than a missed one (plan risk #1). `guesses` is an autoclosure
    /// so the host's ranked-guess computation (typo-variant probes + re-ranks) is paid
    /// only after every cheap guard above it passes.
    static func decide(word: String,
                       isMisspelled: Bool,
                       guesses: @autoclosure () -> [String],
                       userRejected: Set<String>,
                       isUserKnownWord: Bool = false) -> Decision {
        guard word.count >= 2 else { return .keep }                    // single letters: autocap's job
        guard !word.contains(where: { $0.isNumber }) else { return .keep }
        guard word != word.uppercased() else { return .keep }           // acronyms
        guard !userRejected.contains(word.lowercased()) else { return .keep }
        guard !isUserKnownWord else { return .keep }                    // learned words (design §2)
        guard isMisspelled, let guess = guesses().first else { return .keep }
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
    /// Stable three-slot bar model: slot 0 is the literal (or empty), slots 1–2 are
    /// candidates (or empty placeholders). Empty word → three empty slots at rest.
    static func suggestions(word: String,
                            guesses: [String],
                            completions: [String]) -> [Suggestion] {
        if word.isEmpty {
            return [.empty, .empty, .empty]
        }
        var seen: Set<String> = [word.lowercased()]
        var candidates: [String] = []
        for candidate in guesses + completions {
            let key = candidate.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            candidates.append(candidate)
            if candidates.count == 2 { break }
        }
        var slots: [Suggestion] = [.literal(word)]
        slots.append(contentsOf: candidates.map { .candidate($0) })
        while slots.count < 3 { slots.append(.empty) }
        return Array(slots.prefix(3))
    }

    /// Supplementary-lexicon (contacts + Text Replacement) expansion for a finished word.
    /// Case-insensitive on the shortcut; expansion wins over spell correction at a boundary.
    /// `lexicon` keys must be lowercased (see `QwertySpellChecker`).
    static func lexiconExpansion(word: String, lexicon: [String: String]) -> String? {
        guard !word.isEmpty else { return nil }
        return lexicon[word.lowercased()]
    }

    /// Preserves the user's casing shape when applying a correction or repair: a leading
    /// capital carries over ("Teh" → "The") and an all-caps word stays all-caps
    /// ("HELLLO" → "HELLO"). `decide()` never reaches the all-caps branch (its acronym
    /// guard keeps all-caps words untouched); typo-variant repair does.
    static func matchCase(of source: String, to candidate: String) -> String {
        if source.count > 1, source == source.uppercased(), source != source.lowercased() {
            return candidate.uppercased()
        }
        guard let first = source.first, first.isUppercase,
              !source.dropFirst().contains(where: { $0.isUppercase }) else { return candidate }
        return candidate.prefix(1).uppercased() + candidate.dropFirst()
    }
}

/// Typed, stable model for the keyboard suggestion strip. The view exposes this as
/// `QwertySuggestionBarView.State`; it lives in the shared correction module so the app
/// test target can verify the state machine without importing the keyboard extension target.
enum QwertySuggestionBarState: Equatable {
    enum Content: Equatable {
        case suggestion(QwertyAutocorrect.Suggestion)
        case corrected(original: String, replacement: String)
        case undoLiteral(String)
        case empty
    }

    case suggestions([QwertyAutocorrect.Suggestion])
    case corrected(original: String, replacement: String)

    var slots: [Content] {
        let contents: [Content]
        switch self {
        case .suggestions(let suggestions):
            contents = suggestions.prefix(3).map {
                $0 == .empty ? .empty : .suggestion($0)
            }
        case .corrected(let original, let replacement):
            contents = [
                .corrected(original: original, replacement: replacement),
                .undoLiteral(original)
            ]
        }
        return Array((contents + Array(repeating: .empty, count: 3)).prefix(3))
    }

    func isNewCandidateImpression(comparedTo previous: QwertySuggestionBarState) -> Bool {
        guard self != previous else { return false }
        return slots.contains {
            if case .suggestion(.candidate) = $0 { return true }
            return false
        }
    }
}

struct QwertySpellAnalysis: Equatable {
    let isMisspelled: Bool
    let guesses: [String]
    let completions: [String]
}

/// The production correction evaluator accepts this narrow spell-checking seam so its
/// orchestration can be characterized deterministically while the release gate uses the
/// exact `UITextChecker` implementation below.
protocol QwertyCorrectionSpellChecking: AnyObject {
    func analyze(word: String) -> QwertySpellAnalysis
    func isMisspelled(word: String) -> Bool
}

/// Sole `UITextChecker` implementation for both live typing and the release evidence.
final class QwertySystemSpellChecker: QwertyCorrectionSpellChecking {
    private let language: String
    private let checker: UITextChecker

    init(language: String = "en_US", checker: UITextChecker = UITextChecker()) {
        self.language = language
        self.checker = checker
    }

    func analyze(word: String) -> QwertySpellAnalysis {
        guard !word.isEmpty else {
            return QwertySpellAnalysis(isMisspelled: false, guesses: [], completions: [])
        }
        let misspelled = misspelling(in: word)
        let guesses = misspelled.map {
            checker.guesses(forWordRange: $0, in: word, language: language) ?? []
        } ?? []
        let completions = checker.completions(
            forPartialWordRange: NSRange(location: 0, length: word.utf16.count),
            in: word,
            language: language) ?? []
        return QwertySpellAnalysis(isMisspelled: misspelled != nil,
                                   guesses: guesses,
                                   completions: completions)
    }

    func isMisspelled(word: String) -> Bool {
        guard !word.isEmpty else { return false }
        return misspelling(in: word) != nil
    }

    private func misspelling(in word: String) -> NSRange? {
        let range = checker.rangeOfMisspelledWord(
            in: word,
            range: NSRange(location: 0, length: word.utf16.count),
            startingAt: 0,
            wrap: false,
            language: language)
        return range.location == NSNotFound ? nil : range
    }
}

struct QwertyCorrectionEvaluation: Equatable {
    enum ApplyPolicy: Equatable {
        case keep
        case suggestOnly(candidate: String)
        case autoApply(original: String, replacement: String)
    }

    let analysis: QwertySpellAnalysis
    let rankedGuesses: [String]
    let rankedCompletions: [String]
    let suggestionSlots: [QwertyAutocorrect.Suggestion]
    let applyPolicy: ApplyPolicy
}

/// Complete correction path used at the keyboard boundary and by confidence evidence:
/// supplementary expansion, system spell analysis, frequency ordering, checker-validated
/// typo variants, personal ordering, confidence decision, and final apply policy.
struct QwertyProductionCorrectionEvaluator {
    private let checker: QwertyCorrectionSpellChecking
    private let frequencyLexicon: QwertyFrequencyLexicon
    private let supplementaryLexicon: [String: String]

    init(checker: QwertyCorrectionSpellChecking,
         frequencyLexicon: QwertyFrequencyLexicon,
         supplementaryLexicon: [String: String] = [:]) {
        self.checker = checker
        self.frequencyLexicon = frequencyLexicon
        self.supplementaryLexicon = supplementaryLexicon
    }

    func evaluate(word: String,
                  userRejected: Set<String> = [],
                  isUserKnownWord: Bool = false,
                  personalBoost: (String) -> Int = { _ in 0 },
                  isPersonalCandidate: (String) -> Bool = { _ in false })
        -> QwertyCorrectionEvaluation {
        if let expansion = QwertyAutocorrect.lexiconExpansion(
            word: word, lexicon: supplementaryLexicon) {
            let emptyAnalysis = QwertySpellAnalysis(isMisspelled: false,
                                                    guesses: [],
                                                    completions: [])
            return QwertyCorrectionEvaluation(
                analysis: emptyAnalysis,
                rankedGuesses: [],
                rankedCompletions: [],
                suggestionSlots: QwertyAutocorrect.suggestions(
                    word: word, guesses: [expansion], completions: []),
                applyPolicy: .autoApply(original: word, replacement: expansion)
            )
        }

        let analysis = checker.analyze(word: word)
        let frequencyRankedGuesses = frequencyLexicon.rerankKnown(analysis.guesses)
        let augmentedGuesses: [String]
        if analysis.isMisspelled {
            augmentedGuesses = QwertyTypoVariants.augment(
                guesses: frequencyRankedGuesses,
                word: word,
                isRealWord: { !checker.isMisspelled(word: $0) })
        } else {
            augmentedGuesses = frequencyRankedGuesses
        }
        let rankedGuesses = QwertyAutocorrect.rankCandidates(
            augmentedGuesses, personalBoost: personalBoost)
        let rankedCompletions = QwertyAutocorrect.rankCandidates(
            frequencyLexicon.rerank(analysis.completions),
            personalBoost: personalBoost)
        let slots = QwertyAutocorrect.suggestions(word: word,
                                                  guesses: rankedGuesses,
                                                  completions: rankedCompletions)
        let correction = QwertyAutocorrect.decide(
            word: word,
            isMisspelled: analysis.isMisspelled,
            guesses: rankedGuesses,
            userRejected: userRejected,
            isUserKnownWord: isUserKnownWord)
        let applyPolicy: QwertyCorrectionEvaluation.ApplyPolicy
        switch correction {
        case .keep:
            applyPolicy = .keep
        case .replace(let candidate):
            let checkerIndex = analysis.guesses.firstIndex {
                $0.caseInsensitiveCompare(candidate) == .orderedSame
            } ?? Int.max
            let runner = rankedGuesses.first {
                $0.caseInsensitiveCompare(candidate) != .orderedSame
            }
            let confidence = QwertyAutocorrect.autoApplyDecision(
                word: word,
                candidate: candidate,
                checkerIndex: checkerIndex,
                candidateFrequencyRank: frequencyLexicon.rank(of: candidate),
                runnerUpFrequencyRank: runner.flatMap(frequencyLexicon.rank(of:)),
                isPersonalCandidate: isPersonalCandidate(candidate))
            applyPolicy = confidence == .autoApply
                ? .autoApply(original: word, replacement: candidate)
                : .suggestOnly(candidate: candidate)
        }
        return QwertyCorrectionEvaluation(
            analysis: analysis,
            rankedGuesses: rankedGuesses,
            rankedCompletions: rankedCompletions,
            suggestionSlots: slots,
            applyPolicy: applyPolicy)
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


extension QwertyAutocorrect {
    /// Confidence-gated auto-apply. Candidate ordering remains separate from this decision.
    static func autoApplyDecision(word: String,
                                  candidate: String,
                                  checkerIndex: Int,
                                  candidateFrequencyRank: Int?,
                                  runnerUpFrequencyRank: Int?,
                                  isPersonalCandidate: Bool) -> QwertyCorrectionConfidence.Decision {
        let features = QwertyCorrectionConfidence.Features(
            typedLength: word.count,
            editDistance: QwertyCorrectionConfidence.editDistance(word, candidate),
            firstCheckerIndex: checkerIndex,
            candidateFrequencyRank: candidateFrequencyRank,
            runnerUpFrequencyRank: runnerUpFrequencyRank,
            isPersonalCandidate: isPersonalCandidate
        )
        return QwertyCorrectionConfidence.decide(features)
    }
}
