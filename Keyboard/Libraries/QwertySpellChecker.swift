import UIKit

/// Thin adapter around the system spell-check services — the only place the extension talks
/// to `UITextChecker`/`UILexicon`. Both are on-device and work with Full Access off
/// (technical doc §1), so core typing satisfies App Review 4.4.1 by construction.
final class QwertySpellChecker: QwertyCorrectionSpellChecking {
    typealias Analysis = QwertySpellAnalysis

    /// The same implementation the opt-in confidence release gate instantiates.
    private let checker = QwertySystemSpellChecker()

    /// Contacts names + Settings → Text Replacement shortcuts, keyed by lowercased shortcut.
    /// Populated asynchronously — the Phase-0 lexicon spike, live as a real code path.
    private(set) var lexicon: [String: String] = [:]

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
                            userRejected: Set<String>,
                            isUserKnownWord: Bool,
                            personalBoost: (String) -> Int,
                            isPersonalCandidate: (String) -> Bool)
        -> QwertyCorrectionEvaluation {
        QwertyProductionCorrectionEvaluator(
            checker: self,
            frequencyLexicon: frequencyLexicon,
            supplementaryLexicon: lexicon
        ).evaluate(
            word: word,
            userRejected: userRejected,
            isUserKnownWord: isUserKnownWord,
            personalBoost: personalBoost,
            isPersonalCandidate: isPersonalCandidate)
    }

    func loadLexicon(from controller: UIInputViewController) {
        controller.requestSupplementaryLexicon { [weak self] lexicon in
            var entries: [String: String] = [:]
            for entry in lexicon.entries {
                entries[entry.userInput.lowercased()] = entry.documentText
            }
            DispatchQueue.main.async {
                self?.lexicon = entries
            }
        }
    }
}
