import Foundation

/// Mirrors `UITextAutocapitalizationType` (same raw values) without importing UIKit, keeping
/// the decision logic pure and testable — the keyboard bridges the trait's `rawValue` directly.
enum QwertyAutocapPolicy: Int {
    case none = 0
    case words = 1
    case sentences = 2
    case allCharacters = 3
}

/// Self-implemented autocapitalization (there is no keystroke-level OS assist — technical
/// doc §4): given the host field's policy and the text before the caret, decides whether
/// shift should auto-engage. Feed the verdict to `QwertyShiftMachine.evaluateAutocap`.
enum QwertyAutocap {
    /// Closing quotes/brackets that may sit between a sentence terminator and its space,
    /// as in: He said "stop." Next sentence.
    private static let closers: Set<Character> = ["\"", "'", ")", "]", "»", "\u{201D}", "\u{2019}"]

    static func shouldCapitalize(policy: QwertyAutocapPolicy, before context: String?) -> Bool {
        let text = context ?? ""
        switch policy {
        case .none:
            return false
        case .allCharacters:
            return true
        case .words:
            guard let last = text.last else { return true }
            return last.isWhitespace
        case .sentences:
            return sentenceBoundary(before: text)
        }
    }

    private static func sentenceBoundary(before text: String) -> Bool {
        var rest = Substring(text)
        var trailingSpaces = 0
        var sawNewline = false
        while let last = rest.last, last == " " || last == "\t" || last.isNewline {
            if last.isNewline { sawNewline = true } else { trailingSpaces += 1 }
            rest = rest.dropLast()
        }
        if rest.isEmpty { return true }   // document start (possibly behind whitespace)
        if sawNewline { return true }     // fresh line or paragraph
        guard trailingSpaces >= 1 else { return false }  // terminator needs a space after it
        while let last = rest.last, closers.contains(last) { rest = rest.dropLast() }
        guard let last = rest.last else { return false }
        return last == "." || last == "!" || last == "?"
    }
}
