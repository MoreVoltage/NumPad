import Foundation

/// After-insertion layer bounce rules, matching the system keyboard: typing an apostrophe or
/// a space on a symbol layer returns to letters; everything else stays put so numeric runs
/// like "$5.99" don't bounce mid-entry.
enum QwertyLayerRules {
    /// The system keyboard returns to letters after a space on the symbol layers. Matches
    /// observed behavior but is flagged for device verification in the Phase-3 parity QA
    /// gate (plan §0.1) — flip this if the side-by-side check disagrees.
    static let returnToLettersAfterSpace = true

    private static let bounceCharacters: Set<String> = ["'", "\u{2019}"]

    static func layer(afterInserting text: String, on layer: QwertyLayer) -> QwertyLayer {
        guard layer != .letters else { return .letters }
        if bounceCharacters.contains(text) { return .letters }
        if returnToLettersAfterSpace && text == " " { return .letters }
        return layer
    }
}
