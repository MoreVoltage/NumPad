import Foundation
import UIKit

/// Field intent and user preferences are independent. Hiding the suggestion bar must
/// not disable enabled autocorrection, and a technical field must preserve literal input.
struct QwertyTypingPolicy: Equatable {
    let allowsAutocorrect: Bool
    let showsSuggestions: Bool
    let allowsTextReplacement: Bool
    let allowsLearning: Bool
    let usesSmartQuotes: Bool
    let adjustsPunctuationSpacing: Bool

    var needsEvaluation: Bool { allowsAutocorrect || showsSuggestions }

    init(autocorrectEnabled: Bool, suggestionsEnabled: Bool,
         keyboardType: UIKeyboardType = .default,
         autocorrectionType: UITextAutocorrectionType = .default,
         spellCheckingType: UITextSpellCheckingType = .default,
         smartQuotesType: UITextSmartQuotesType = .default,
         programmerMode: Bool = false, before: String? = nil) {
        let literalTypes: Set<UIKeyboardType> = [
            .URL, .emailAddress, .numberPad, .phonePad, .namePhonePad,
            .decimalPad, .asciiCapableNumberPad
        ]
        let token = String((before ?? "").suffix(256).split(whereSeparator: \.isWhitespace).last ?? "")
        let literalToken = token.contains("@") || token.contains("://")
            || token.hasPrefix("www.") || token.hasPrefix("/") || token.contains("_")
        let literal = programmerMode || literalTypes.contains(keyboardType) || literalToken
        allowsAutocorrect = autocorrectEnabled && autocorrectionType != .no && !literal
        showsSuggestions = suggestionsEnabled && spellCheckingType != .no && !literal
        allowsTextReplacement = autocorrectionType != .no && !literal
        allowsLearning = autocorrectionType != .no && !literal
        usesSmartQuotes = smartQuotesType != .no && !literal
        adjustsPunctuationSpacing = autocorrectionType != .no && !literal
    }
}

/// Transient edit identity only; never persisted or included in analytics. Context is
/// bounded, and selection callbacks advance revision even when two locations look alike.
struct QwertyDocumentSnapshot: Equatable {
    let document: UUID
    let revision: UInt64
    let before: String?
    let after: String?
    let selection: String?
    let policy: QwertyTypingPolicy

    init(document: UUID, revision: UInt64, before: String?, after: String?,
         selection: String?, policy: QwertyTypingPolicy) {
        self.document = document
        self.revision = revision
        self.before = before.map { String($0.suffix(256)) }
        self.after = after.map { String($0.prefix(256)) }
        self.selection = selection.map { String($0.prefix(256)) }
        self.policy = policy
    }

    var wordForAssistance: String? {
        guard selection?.isEmpty != false,
              let word = QwertyAutocorrect.currentWord(before: before),
              word.count < 256 else { return nil }
        // A suffix belongs to the same word: replacing only the prefix would corrupt it.
        if let next = after?.first, !QwertyAutocorrect.isBoundary(String(next)) {
            return nil
        }
        return word
    }
}

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

enum QwertySpellCheckerOperation: Int {
    case misspelling = 1
    case guesses
    case completions
}

/// Sole `UITextChecker` implementation for both live typing and the release evidence.
final class QwertySystemSpellChecker: QwertyCorrectionSpellChecking {
    private let language: String
    private let checker: UITextChecker
    private let onOperation: (QwertySpellCheckerOperation) -> Void

    init(language: String = "en_US",
         checker: UITextChecker = UITextChecker(),
         onOperation: @escaping (QwertySpellCheckerOperation) -> Void = { _ in }) {
        self.language = language
        self.checker = checker
        self.onOperation = onOperation
    }

    func analyze(word: String) -> QwertySpellAnalysis {
        guard !word.isEmpty else {
            return QwertySpellAnalysis(isMisspelled: false, guesses: [], completions: [])
        }
        let misspelled = misspelling(in: word)
        let guesses: [String]
        if let misspelled {
            onOperation(.guesses)
            guesses = checker.guesses(
                forWordRange: misspelled, in: word, language: language) ?? []
        } else {
            guesses = []
        }
        onOperation(.completions)
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
        onOperation(.misspelling)
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

/// Boundary reducer shared with the app test target. The keyboard extension owns the
/// persistence side effect through `recordAcceptance`; this model decides whether a completed
/// evaluation justifies calling it and what the host should do with the typed word.
enum QwertyBoundaryCorrection {
    enum Action: Equatable {
        case preserveTypedText
        case autoApply(original: String, replacement: String)
    }

    static func resolve(evaluation: QwertyCorrectionEvaluation?,
                        recordAcceptance: () -> Void) -> Action {
        guard let evaluation else {
            return .preserveTypedText
        }
        switch evaluation.applyPolicy {
        case .autoApply(let original, let replacement):
            return .autoApply(original: original, replacement: replacement)
        case .suggestOnly, .keep:
            recordAcceptance()
            return .preserveTypedText
        }
    }
}

/// Immutable identity for one live-suggestion computation. Every input that can change the
/// visible ordering or correction policy belongs in this value so duplicate UIKit callbacks
/// can safely share work and cached results cannot survive a semantic change.
struct QwertySuggestionRequest: Hashable {
    let word: String
    let lexiconGeneration: UInt64
    let personalizationGeneration: UInt64
    let rejectedWordsGeneration: UInt64

    init(word: String,
         lexiconGeneration: UInt64,
         personalizationGeneration: UInt64,
         rejectedWordsGeneration: UInt64) {
        self.word = word
        self.lexiconGeneration = lexiconGeneration
        self.personalizationGeneration = personalizationGeneration
        self.rejectedWordsGeneration = rejectedWordsGeneration
    }
}

struct QwertySuggestionCoordinatorMetrics: Equatable {
    fileprivate(set) var requests = 0
    fileprivate(set) var coalesces = 0
    fileprivate(set) var cacheHits = 0
    fileprivate(set) var evaluations = 0
    fileprivate(set) var staleDiscards = 0
    fileprivate(set) var resultApplies = 0
}

enum QwertySuggestionCoordinatorEvent: Int {
    case request = 1
    case coalesce
    case cacheHit
    case evaluation
    case staleDiscard
    case resultApply
}

/// Main-actor scheduler for suggestion enrichment. Text insertion remains synchronous in the
/// host; this owner yields once before checker work, coalesces the direct-insert/UIKit callback
/// pair, and retains only a bounded exact-result cache. It deliberately does not dispatch
/// `UITextChecker` to a background queue: the SDK marks that API `@MainActor`.
@MainActor
final class QwertySuggestionCoordinator<Result> {
    typealias Work = @MainActor () -> Void
    typealias Scheduler = (@escaping Work) -> Void

    private let capacity: Int
    private let schedule: Scheduler
    private let onEvent: (QwertySuggestionCoordinatorEvent) -> Void
    private var cache: [QwertySuggestionRequest: Result] = [:]
    private var recency: [QwertySuggestionRequest] = []

    private var serial: UInt64 = 0
    private var latestRequest: QwertySuggestionRequest?
    private var pendingSerial: UInt64?
    private var pendingRequest: QwertySuggestionRequest?
    private var pendingEvaluation: (() -> Result)?
    private var pendingApply: ((QwertySuggestionRequest, Result) -> Bool)?

    private(set) var metrics = QwertySuggestionCoordinatorMetrics()

    init(capacity: Int = 256,
         schedule: Scheduler? = nil,
         onEvent: @escaping (QwertySuggestionCoordinatorEvent) -> Void = { _ in }) {
        self.capacity = max(capacity, 1)
        self.onEvent = onEvent
        self.schedule = schedule ?? { work in
            Task { @MainActor in
                await Task.yield()
                work()
            }
        }
    }

    /// `input` is captured by value inside the scheduled closure. The host passes snapshots,
    /// never closures that re-read mutable document/personalization state during evaluation.
    func request<Input>(_ request: QwertySuggestionRequest,
                        input: Input,
                        evaluate: @escaping (Input) -> Result,
                        apply: @escaping (QwertySuggestionRequest, Result) -> Bool) {
        metrics.requests += 1
        onEvent(.request)
        latestRequest = request

        if let cached = cachedResult(for: request) {
            applyResult(cached, for: request, using: apply)
            return
        }

        if pendingRequest == request {
            metrics.coalesces += 1
            onEvent(.coalesce)
            // The exact fingerprint makes the pending value reusable. Keep the original
            // evaluation snapshot and replace only the UI callback with the newest caller.
            pendingApply = apply
            return
        }

        serial &+= 1
        let requestSerial = serial
        pendingSerial = requestSerial
        pendingRequest = request
        pendingEvaluation = { evaluate(input) }
        pendingApply = apply

        schedule { [weak self] in
            self?.run(serial: requestSerial)
        }
    }

    /// Fresh exact results are reused by the word-boundary path. A miss is intentionally
    /// non-blocking: callers preserve the typed word rather than putting checker work back in
    /// the key-commit stack.
    func cachedResult(for request: QwertySuggestionRequest) -> Result? {
        guard let result = cache[request] else { return nil }
        metrics.cacheHits += 1
        onEvent(.cacheHit)
        touch(request)
        return result
    }

    /// Invalidates scheduled work without dropping useful exact results (caret move / empty
    /// word). A later request may still hit the bounded cache if its complete fingerprint
    /// matches.
    func cancelPending() {
        serial &+= 1
        latestRequest = nil
        pendingSerial = nil
        pendingRequest = nil
        pendingEvaluation = nil
        pendingApply = nil
    }

    /// Semantic invalidation (lexicon or personalization reset/settings change) clears both
    /// pending and cached work.
    func invalidate() {
        cancelPending()
        cache.removeAll(keepingCapacity: true)
        recency.removeAll(keepingCapacity: true)
    }

    private func run(serial requestSerial: UInt64) {
        guard pendingSerial == requestSerial,
              let request = pendingRequest,
              let evaluate = pendingEvaluation,
              let apply = pendingApply else {
            metrics.staleDiscards += 1
            onEvent(.staleDiscard)
            return
        }

        metrics.evaluations += 1
        onEvent(.evaluation)
        let result = evaluate()
        insert(result, for: request)

        pendingSerial = nil
        pendingRequest = nil
        pendingEvaluation = nil
        pendingApply = nil

        guard latestRequest == request, serial == requestSerial else {
            metrics.staleDiscards += 1
            onEvent(.staleDiscard)
            return
        }
        applyResult(result, for: request, using: apply)
    }

    private func applyResult(_ result: Result,
                             for request: QwertySuggestionRequest,
                             using apply: (QwertySuggestionRequest, Result) -> Bool) {
        if apply(request, result) {
            metrics.resultApplies += 1
            onEvent(.resultApply)
        } else {
            metrics.staleDiscards += 1
            onEvent(.staleDiscard)
        }
    }

    private func insert(_ result: Result, for request: QwertySuggestionRequest) {
        if cache[request] == nil, cache.count >= capacity, let oldest = recency.first {
            cache.removeValue(forKey: oldest)
            recency.removeFirst()
        }
        cache[request] = result
        touch(request)
    }

    private func touch(_ request: QwertySuggestionRequest) {
        recency.removeAll { $0 == request }
        recency.append(request)
    }
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
        endImmediateCorrectionScope()
    }

    /// Lifecycle and page transitions end the one-backspace correction window without
    /// treating the corrected word as a user rejection.
    mutating func endImmediateCorrectionScope() {
        pending = nil
    }

    /// The user explicitly accepted a word as typed (the quoted literal slot) — never
    /// auto-correct it again this session.
    mutating func reject(_ word: String) {
        rejectedWords.insert(word.lowercased())
    }

    func peekRevert() -> Revert? {
        guard let correction = pending else { return nil }
        return Revert(deletions: correction.corrected.count,
                      insertion: correction.original,
                      corrected: correction.corrected)
    }

    /// Consume only after the caller confirms the current document context still matches.
    /// A failed predicate leaves both the pending revert and rejected-word set untouched.
    mutating func consumeRevert(matching predicate: (Revert) -> Bool) -> Revert? {
        guard let revert = peekRevert(), predicate(revert),
              let correction = pending else { return nil }
        pending = nil
        rejectedWords.insert(correction.original.lowercased())
        return revert
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
