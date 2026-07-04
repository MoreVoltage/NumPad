import Foundation

/// Ready-made keys offered by the Custom Keyboard editor's "Key Library" palette — a catalog of
/// draggable chips (`CustomKeyboardKeyLibraryView`) the user drops into any slot, or taps to assign
/// to whichever slot is currently selected. Deliberately pure (no UIKit/SwiftUI) so the catalog and
/// its display rules are unit-testable without touching the drag UI; the drag mechanics themselves
/// live entirely in `CustomKeyboardKeyLibraryView` + `CustomKeyboardSectionReorderView` (the
/// isolated drag seam) — this file only describes *what* the palette offers, never *how* it's
/// dragged.
enum CustomKeyboardKeyLibrary {
    /// One palette entry. `token` is exactly what gets stored in a slot (via
    /// `CustomKeyboardEditorModel.setKey`) when the chip is dropped or tapped; `label` is what the
    /// chip — and the slot it lands in — displays (`CustomKeys.displayName(for: token)` agrees with
    /// this for every chip here, so the assigned slot and the source chip always read the same).
    /// `subtitle` is a secondary caption shown only on the chip itself (e.g. the familiar `{date}`
    /// spelling users already know from Snippets); `nil` for chips that need no further explanation.
    struct Chip: Equatable, Identifiable {
        let token: String
        let label: String
        let subtitle: String?
        var id: String { token }

        init(token: String, label: String, subtitle: String? = nil) {
            self.token = token
            self.label = label
            self.subtitle = subtitle
        }
    }

    /// Curated common characters offered alongside the function/date-time tokens. Deliberately a
    /// small, opinionated set (not the full `CustomKeys.palette`) — the Key Library is a fast path
    /// for the most commonly wanted slot values, not an exhaustive picker.
    static let curatedCharacters = [",", ".", "%", "$", "€", "(", ")", "#"]

    /// Every chip the palette offers, in display order: the two date/time tokens (mandatory — insert
    /// the *live* value via the same `DateTimeTokens` expansion the Date & Time pack and Snippets
    /// use, not the literal braces), the existing action tokens (cursor left/right, Tab, Hide — the
    /// exact strings `CustomKeys` already uses for the right-side slots, so a chip dropped here
    /// behaves identically to picking the same token there), then the curated characters.
    static let chips: [Chip] = [
        Chip(token: DateTimeTokens.keyToken(for: "date"),
             label: CustomKeys.displayName(for: DateTimeTokens.keyToken(for: "date")),
             subtitle: Snippet.dateToken),
        Chip(token: DateTimeTokens.keyToken(for: "time"),
             label: CustomKeys.displayName(for: DateTimeTokens.keyToken(for: "time")),
             subtitle: Snippet.timeToken),
        Chip(token: CustomKeys.cursorLeftToken, label: CustomKeys.displayName(for: CustomKeys.cursorLeftToken)),
        Chip(token: CustomKeys.cursorRightToken, label: CustomKeys.displayName(for: CustomKeys.cursorRightToken)),
        Chip(token: CustomKeys.tabToken, label: CustomKeys.displayName(for: CustomKeys.tabToken)),
        Chip(token: CustomKeys.dismissToken, label: CustomKeys.displayName(for: CustomKeys.dismissToken)),
    ] + curatedCharacters.map { Chip(token: $0, label: $0) }

    /// Whether the Key Library should be shown at all: only alongside the drag-reorder preview. When
    /// the escape hatch reverts the editor to the legacy static rows, dragging is unavailable there
    /// too, so the palette (a drag-first affordance) is hidden — the legacy rows keep their own
    /// existing (non-drag) token palette unchanged.
    static func isVisible(dragReorderActive: Bool) -> Bool { dragReorderActive }
}
