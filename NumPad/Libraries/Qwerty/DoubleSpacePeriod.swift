import Foundation

/// Self-implemented double-space → period shortcut (no API assist exists — technical doc §4).
/// On every space tap the keyboard asks for a decision; `.replacePreviousSpaceWithPeriodSpace`
/// is applied as one `deleteBackward()` followed by `insertText(". ")`.
enum DoubleSpacePeriod {
    /// Maximum gap between the two space taps for the shortcut to fire. The system keyboard
    /// time-gates this but the native window is unpublished — parity-tune on device during
    /// the Phase-3 QA gate (plan §0.1).
    static let maxInterval: TimeInterval = 0.75

    enum Decision: Equatable {
        case insertSpace
        case replacePreviousSpaceWithPeriodSpace

        /// `deleteBackward()` calls to apply before inserting.
        var deletions: Int { self == .replacePreviousSpaceWithPeriodSpace ? 1 : 0 }
        /// The text to insert.
        var insertion: String { self == .replacePreviousSpaceWithPeriodSpace ? ". " : " " }
    }

    static func decision(before context: String?,
                         secondsSinceLastSpaceTap: TimeInterval?,
                         enabled: Bool) -> Decision {
        guard enabled,
              let gap = secondsSinceLastSpaceTap, gap <= maxInterval,
              let text = context, text.hasSuffix(" "), !text.hasSuffix("  ")
        else { return .insertSpace }
        guard let beforeSpace = text.dropLast().last else { return .insertSpace }
        return isPeriodEligible(beforeSpace) ? .replacePreviousSpaceWithPeriodSpace : .insertSpace
    }

    /// A period is only substituted after word-like content: letters, digits, or closing
    /// quotes/brackets — never after punctuation ("hello. " must not become "hello.. ").
    private static func isPeriodEligible(_ character: Character) -> Bool {
        if character.isLetter || character.isNumber { return true }
        let closers: Set<Character> = ["\"", "'", ")", "]", "}", "\u{201D}", "\u{2019}", "»"]
        return closers.contains(character)
    }
}
