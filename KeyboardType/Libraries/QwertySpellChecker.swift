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
        let range = NSRange(location: 0, length: word.utf16.count)
        let misspelledRange = checker.rangeOfMisspelledWord(in: word,
                                                            range: range,
                                                            startingAt: 0,
                                                            wrap: false,
                                                            language: language)
        let isMisspelled = misspelledRange.location != NSNotFound
        let guesses = isMisspelled
            ? (checker.guesses(forWordRange: misspelledRange, in: word, language: language) ?? [])
            : []
        let completions = checker.completions(forPartialWordRange: range,
                                              in: word,
                                              language: language) ?? []
        return Analysis(isMisspelled: isMisspelled, guesses: guesses, completions: completions)
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
