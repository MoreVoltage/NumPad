import Foundation

// Editor-only pure logic: grid-position lookup, drag-reorder, append, plus the
// "add key" palette and per-token display glyphs. No UIKit — unit-tested in NumPadTests
// (the keyboard extension never needs these, so this file is app-target only).

extension KeyboardLayout {
    /// The row/index of a key by id, or nil if it isn't in the grid.
    func position(of id: UUID) -> GridPosition? {
        for (r, row) in rows.enumerated() {
            if let i = row.firstIndex(where: { $0.id == id }) {
                return GridPosition(row: r, index: i)
            }
        }
        return nil
    }

    /// Moves `draggedID` so it sits immediately before `targetID`, correcting for the
    /// index shift caused by first removing the dragged key from the same row.
    /// No-op when either id is absent (e.g. a stale drag payload).
    func reordering(_ draggedID: UUID, before targetID: UUID) -> KeyboardLayout {
        guard let from = position(of: draggedID), let to = position(of: targetID) else { return self }
        let adjusted = (from.row == to.row && from.index < to.index) ? to.index - 1 : to.index
        return movingKey(draggedID, to: GridPosition(row: to.row, index: adjusted))
    }

    /// Appends a key to the end of the last row (the natural "add a key" target).
    func appendingKey(_ key: KeyDefinition) -> KeyboardLayout {
        guard let last = rows.indices.last else { return insertingKey(key, at: GridPosition(row: 0, index: 0)) }
        return insertingKey(key, at: GridPosition(row: last, index: rows[last].count))
    }
}

extension KeyToken {
    /// The glyph shown for this token in the editor. For v1 the inserted value and the
    /// label are the same (the display/value split is a Phase-1 follow-up).
    var displayLabel: String {
        switch self {
        case .digit(let s), .op(let s): return s
        case .decimalSeparator: return "."
        case .delete: return "⌫"
        case .ret: return "return"
        case .space: return "space"
        case .tab: return "⇥"
        case .hide: return "⌄"
        case .calc: return "="
        case .cursor(let d):
            switch d {
            case .left: return "◀"
            case .right: return "▶"
            case .up: return "▲"
            case .down: return "▼"
            }
        case .snippet: return "❝"
        case .pack: return "▦"
        case .overlay: return "▤"
        case .noop: return "·"
        }
    }
}

/// The tokens offered in the editor's "add key" palette — exactly the v1 renderer-supported
/// set (everything here maps to a non-`.blank` `KeyRenderKind`, guaranteed by test).
enum KeyTokenPalette {
    static let tokens: [KeyToken] =
        (0...9).map { KeyToken.digit(String($0)) }
        + [.decimalSeparator]
        + ["+", "-", "*", "/", "=", "%"].map(KeyToken.op)
        + [.delete, .ret, .space]
}
