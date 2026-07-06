import Foundation

/// Pure array-reorder math for the Custom Keyboard editor's drag-and-drop (Option B — see
/// docs/plans/2026-07-03-editor-ux-research.md). Deliberately knows nothing about
/// `CustomKeyboardConfig`/sections/UIKit — it operates on a plain `[String]`, so it is trivial to
/// unit-test and trivial to swap out from under `CustomKeyboardEditorModel.moveKey(in:from:to:)` if
/// the drag surface itself is ever replaced (see the fallback seam note on
/// `CustomKeyboardSectionReorderView`).
enum CustomKeyboardReorder {
    /// Moves the element at `source` to `destination`, mirroring the exact semantics
    /// `UICollectionViewDropCoordinator` reorder samples use: remove at `source`, then insert at
    /// `destination` into what's left. `destination` may equal `items.count` (one past the last
    /// valid index) to mean "move to the end" — this is what UIKit reports when a drop resolves
    /// past the last cell, so the caller does not need to special-case it.
    ///
    /// Pure; always returns a new array (or `items` itself, unchanged, for a no-op). No-ops
    /// (returns `items` unchanged) when:
    /// - `items` has fewer than 2 elements (nothing to reorder — covers the empty and
    ///   single-item cases),
    /// - `source` is out of bounds,
    /// - `destination` is negative,
    /// - `source == destination` (dropping a key back where it started).
    static func moved(_ items: [String], from source: Int, to destination: Int) -> [String] {
        guard items.count > 1,
              items.indices.contains(source),
              destination >= 0,
              source != destination else { return items }
        var result = items
        let key = result.remove(at: source)
        let insertionIndex = min(destination, result.count)
        result.insert(key, at: insertionIndex)
        return result
    }
}
