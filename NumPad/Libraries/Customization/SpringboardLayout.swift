import CoreGraphics
import Foundation

// Pure springboard-reorder math for the layout editor: flatten a grid to a single
// ordered list, re-chunk a list back into fixed-width rows, reflow a drag move, map a
// finger position to a flat insertion slot, and report which tokens are locked in place.
// No UIKit, no input mutation — every function returns a fresh value. App-target only
// (editor math; the keyboard extension never reorders keys).
enum SpringboardLayout {
    /// Springboard grid width: the editor always re-flows to this many columns.
    static let columns = 5

    /// Collapse a layout's rows into one ordered array, top-to-bottom, left-to-right.
    static func flatten(_ layout: KeyboardLayout) -> [KeyDefinition] {
        layout.rows.flatMap { $0 }
    }

    /// Chunk a flat array back into rows of width `columns` (the last row may be short).
    static func rebuild(_ items: [KeyDefinition], columns: Int = columns) -> [[KeyDefinition]] {
        guard columns > 0 else { return items.isEmpty ? [] : [items] }
        return stride(from: 0, to: items.count, by: columns).map { start in
            Array(items[start ..< min(start + columns, items.count)])
        }
    }

    /// Reflow-move: remove the element at `from` and re-insert it at `to`. The remove
    /// shifts later indices down by one, so for [0,1,2,3,4,5] moving(from:0,to:3) yields
    /// [1,2,3,0,4,5]. Out-of-range `from` is a no-op; `to` is clamped into the new bounds.
    static func moving(_ items: [KeyDefinition], from: Int, to: Int) -> [KeyDefinition] {
        guard items.indices.contains(from) else { return items }
        var out = items
        let element = out.remove(at: from)
        out.insert(element, at: min(max(to, 0), out.count))
        return out
    }

    /// Map a finger position to the nearest flat insertion slot. Adding half a stride
    /// before truncating snaps a point past a cell's midpoint to the next column/row.
    /// Result is clamped to `[0, count]` (an append at `count` is valid).
    static func insertionIndex(at point: CGPoint, cell: CGSize, spacing: CGFloat,
                               columns: Int, count: Int) -> Int {
        guard columns > 0 else { return 0 }
        let strideX = cell.width + spacing
        let strideY = cell.height + spacing
        let col = strideX > 0 ? Int((point.x + strideX / 2) / strideX) : 0
        let row = strideY > 0 ? Int((point.y + strideY / 2) / strideY) : 0
        let raw = row * columns + col
        return min(max(raw, 0), count)
    }

    /// Whether a token is an essential that can't be moved or removed (digits 0–9,
    /// delete, return) — the editor pins these so a layout can never become unusable.
    static func isLocked(_ token: KeyToken) -> Bool {
        KeyboardLayout.essentialTokens.contains(token)
    }
}
