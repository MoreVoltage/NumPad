import Foundation

/// The render/behaviour class a key maps to. Pure (no UIKit) so it's testable here; the keyboard
/// extension turns each kind into a concrete `Item` that the existing tap dispatch already handles.
enum KeyRenderKind: Equatable {
    case insert(String)   // digit / operator → inserts this string
    case separator        // locale-aware decimal separator
    case delete
    case ret
    case space
    case blank            // not yet renderable in v1 (cursor/hide/tab/calc/snippet/pack/overlay/noop)
}

enum KeyboardLayoutRenderer {
    /// Maps a token to its render kind. v1 supports the standard key set; everything else is `.blank`.
    static func renderKind(for token: KeyToken) -> KeyRenderKind {
        switch token {
        case .digit(let s), .op(let s): return .insert(s)
        case .decimalSeparator: return .separator
        case .delete: return .delete
        case .ret: return .ret
        case .space: return .space
        case .cursor, .hide, .tab, .calc, .snippet, .pack, .overlay, .noop: return .blank
        }
    }
}
