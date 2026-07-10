import Foundation

/// A layer of the QWERTY keyboard: the letter grid, the number/symbol layer behind the
/// "123" key, or the secondary symbol layer behind "#+=".
enum QwertyLayer: Equatable {
    case letters
    case symbols
    case extendedSymbols
}

/// What a key does when tapped.
enum QwertyKeyKind: Equatable {
    /// Inserts text; `shifted` is the variant used while shift/caps lock is engaged
    /// (uppercase for letters, identical for digits and symbols).
    case character(String, shifted: String)
    case shift
    case backspace
    case space
    case ret
    case globe
    /// Switches to the given layer — the "123", "ABC", and "#+=" keys.
    case layerSwitch(QwertyLayer)
    /// Flips the entire canvas to the full NumPad keyboard and back — the one-tap numeric
    /// mode that removes the globe-key round-trip (plan §2).
    case numpadFlip
    /// Cycles the top strip through the number row and the QWERTY pack family (owner
    /// decision §0.3). Renders `KeyGlyph.packSwitch`, visually distinct from the globe.
    case packSwitch
    /// Lowers the keyboard — the native iPad bottom-trailing key. Never rendered on iPhone
    /// (system parity: the iPhone keyboard has no dismiss key).
    case dismissKeyboard
    /// A live Date/Time pack key: shows `label`, inserts `DateTimeTokens.value(for: token)`
    /// resolved at tap time.
    case dateTimeToken(label: String, token: String)
    /// A snippet strip key: `label` renders on the keycap; `text` is the RAW snippet body,
    /// expanded ({date}/{time} tokens) and inserted at tap time — mirroring the snippets
    /// overlay's insert-time expansion.
    case snippet(label: String, text: String)
}

/// One key: what it does plus its width in layout units, where a letter key is 1.0 and every
/// full row spans `QwertyLayout.rowUnitWidth`.
struct QwertyKey: Equatable {
    let kind: QwertyKeyKind
    let width: Double
}

/// One rendered row. Margins are empty space (same units) the renderer leaves on either side —
/// the home row's half-key inset, matching the system keyboard.
struct QwertyRow: Equatable {
    let keys: [QwertyKey]
    let leadingMargin: Double
    let trailingMargin: Double

    init(keys: [QwertyKey], leadingMargin: Double = 0, trailingMargin: Double = 0) {
        self.keys = keys
        self.leadingMargin = leadingMargin
        self.trailingMargin = trailingMargin
    }
}
