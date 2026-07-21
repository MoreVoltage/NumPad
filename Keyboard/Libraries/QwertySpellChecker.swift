import UIKit

/// Thin adapter around the system spell-check services — the only place the extension talks
/// to `UITextChecker`/`UILexicon`. Both are on-device and work with Full Access off
/// (technical doc §1), so core typing satisfies App Review 4.4.1 by construction.
final class QwertySpellChecker {

    struct Analysis {
        let isMisspelled: Bool
        let guesses: [String]
        let completions: [String]
    }

    /// V1 is English (plan §2); V2 locales route through §3's per-language sourcing.
    private let language = "en_US"
    private let checker = UITextChecker()

    /// Contacts names + Settings → Text Replacement shortcuts, keyed by lowercased shortcut.
    /// Populated asynchronously — the Phase-0 lexicon spike, live as a real code path.
    private(set) var lexicon: [String: String] = [:]

    /// Suggestion quality guardrail: `completions(forPartialWordRange:)` returns
    /// alphabetically-ordered results on iOS (NSHipster finding, technical doc §2) — a known,
    /// accepted v1 limitation. Guesses are requested first and ranked ahead of completions.
    func analyze(word: String) -> Analysis {
        guard !word.isEmpty else {
            return Analysis(isMisspelled: false, guesses: [], completions: [])
        }
        let misspelled = misspelling(in: word)
        let guesses = misspelled.map {
            checker.guesses(forWordRange: $0, in: word, language: language) ?? []
        } ?? []
        let completions = checker.completions(
            forPartialWordRange: NSRange(location: 0, length: word.utf16.count),
            in: word,
            language: language) ?? []
        return Analysis(isMisspelled: misspelled != nil,
                        guesses: guesses,
                        completions: completions)
    }

    /// Verdict-only probe — no guess or completion computation. Exists for the
    /// typo-variant repair oracle, which may probe dozens of variants per word: `analyze`
    /// would pay a full `guesses(forWordRange:)` for every misspelled probe. Routes
    /// through the same `misspelling(in:)` helper `analyze` uses, so the two verdicts can
    /// never drift.
    func isMisspelled(word: String) -> Bool {
        guard !word.isEmpty else { return false }
        return misspelling(in: word) != nil
    }

    /// The single home of the `rangeOfMisspelledWord` call and its NSNotFound
    /// interpretation — nil means correctly spelled.
    private func misspelling(in word: String) -> NSRange? {
        let range = checker.rangeOfMisspelledWord(
            in: word,
            range: NSRange(location: 0, length: word.utf16.count),
            startingAt: 0,
            wrap: false,
            language: language)
        return range.location == NSNotFound ? nil : range
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
