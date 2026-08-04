import UIKit
import os.signpost

/// Points-of-interest instrumentation for the 2.1 latency gate. Payloads are deliberately
/// contentless: lengths, operation codes, and durations only — never words, candidates,
/// document context, or personal-dictionary contents.
enum QwertyLatencyInstrumentation {
    struct SuggestionInterval {
        fileprivate let id: OSSignpostID
    }

    private static let log = OSLog(
        subsystem: "com.morevoltage.NumPad.Keyboard",
        category: .pointsOfInterest)

    static func measureTextCommit(_ work: () -> Void) {
        let id = OSSignpostID(log: log)
        os_signpost(.begin, log: log, name: "QwertyTextCommit", signpostID: id)
        work()
        os_signpost(.end, log: log, name: "QwertyTextCommit", signpostID: id)
    }

    static func measureCheckerSlice<T>(wordLength: Int, _ work: () -> T) -> T {
        let id = OSSignpostID(log: log)
        os_signpost(.begin, log: log, name: "QwertyCheckerSlice", signpostID: id,
                    "word_length=%{public}d", wordLength)
        let value = work()
        os_signpost(.end, log: log, name: "QwertyCheckerSlice", signpostID: id)
        return value
    }

    static func beginSuggestion(wordLength: Int) -> SuggestionInterval {
        let id = OSSignpostID(log: log)
        os_signpost(.begin, log: log, name: "QwertySuggestionFreshness", signpostID: id,
                    "word_length=%{public}d", wordLength)
        return SuggestionInterval(id: id)
    }

    static func endSuggestion(_ interval: SuggestionInterval, applied: Bool) {
        os_signpost(.end, log: log, name: "QwertySuggestionFreshness",
                    signpostID: interval.id, "applied=%{public}d", applied ? 1 : 0)
    }

    static func coordinatorEvent(_ event: QwertySuggestionCoordinatorEvent) {
        os_signpost(.event, log: log, name: "QwertySuggestionCoordinator",
                    "event=%{public}d", event.rawValue)
    }

    static func checkerCall(_ operation: QwertySpellCheckerOperation) {
        os_signpost(.event, log: log, name: "QwertyCheckerCall",
                    "operation=%{public}d", operation.rawValue)
    }
}

/// Thin adapter around the system spell-check services — the only place the extension talks
/// to `UITextChecker`/`UILexicon`. Both are on-device and work with Full Access off
/// (technical doc §1), so core typing satisfies App Review 4.4.1 by construction.
final class QwertySpellChecker: QwertyCorrectionSpellChecking {
    typealias Analysis = QwertySpellAnalysis

    struct LexiconSnapshot {
        let entries: [String: String]
        let generation: UInt64
    }

    /// The same implementation the opt-in confidence release gate instantiates.
    private let checker = QwertySystemSpellChecker(
        onOperation: QwertyLatencyInstrumentation.checkerCall)

    /// Contacts names + Settings → Text Replacement shortcuts, keyed by lowercased shortcut.
    /// Populated asynchronously — the Phase-0 lexicon spike, live as a real code path.
    private(set) var lexicon: [String: String] = [:]
    private(set) var lexiconGeneration: UInt64 = 0

    var lexiconSnapshot: LexiconSnapshot {
        LexiconSnapshot(entries: lexicon, generation: lexiconGeneration)
    }

    /// Suggestion quality guardrail: `completions(forPartialWordRange:)` returns
    /// alphabetically-ordered results on iOS (NSHipster finding, technical doc §2) — a known,
    /// accepted v1 limitation. Guesses are requested first and ranked ahead of completions.
    func analyze(word: String) -> Analysis {
        checker.analyze(word: word)
    }

    /// Verdict-only probe — no guess or completion computation. Exists for the
    /// typo-variant repair oracle, which may probe dozens of variants per word: `analyze`
    /// would pay a full `guesses(forWordRange:)` for every misspelled probe. Routes
    /// through the same `misspelling(in:)` helper `analyze` uses, so the two verdicts can
    /// never drift.
    func isMisspelled(word: String) -> Bool {
        checker.isMisspelled(word: word)
    }

    /// Constructs the complete shared production evaluator with the extension's live
    /// supplementary lexicon and personalization inputs.
    func evaluateCorrection(word: String,
                            frequencyLexicon: QwertyFrequencyLexicon,
                            supplementaryLexicon: [String: String]? = nil,
                            userRejected: Set<String>,
                            isUserKnownWord: Bool,
                            personalBoost: (String) -> Int,
                            isPersonalCandidate: (String) -> Bool)
        -> QwertyCorrectionEvaluation {
        QwertyProductionCorrectionEvaluator(
            checker: self,
            frequencyLexicon: frequencyLexicon,
            supplementaryLexicon: supplementaryLexicon ?? lexicon
        ).evaluate(
            word: word,
            userRejected: userRejected,
            isUserKnownWord: isUserKnownWord,
            personalBoost: personalBoost,
            isPersonalCandidate: isPersonalCandidate)
    }

    func loadLexicon(from controller: UIInputViewController,
                     completion: (() -> Void)? = nil) {
        controller.requestSupplementaryLexicon { [weak self] lexicon in
            var entries: [String: String] = [:]
            for entry in lexicon.entries {
                entries[entry.userInput.lowercased()] = entry.documentText
            }
            DispatchQueue.main.async {
                guard let self else { return }
                self.lexicon = entries
                self.lexiconGeneration &+= 1
                completion?()
            }
        }
    }
}
