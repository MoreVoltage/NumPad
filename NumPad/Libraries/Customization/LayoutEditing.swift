import Foundation

/// A position in the grid: which row, and which slot within that row.
struct GridPosition: Equatable { var row: Int; var index: Int }

// Pure, immutable editing operations. Each returns a NEW layout; the SwiftUI
// editor's @Observable model is a thin shell that swaps in the result.
extension KeyboardLayout {
    private func withRows(_ rows: [[KeyDefinition]]) -> KeyboardLayout {
        KeyboardLayout(id: id, name: name, rows: rows, keyScale: keyScale, schemaVersion: schemaVersion)
    }

    func removingKey(_ id: UUID) -> KeyboardLayout {
        withRows(rows.map { $0.filter { $0.id != id } })
    }

    func updatingKey(_ id: UUID, _ transform: (inout KeyDefinition) -> Void) -> KeyboardLayout {
        withRows(rows.map { row in
            row.map { key in
                guard key.id == id else { return key }
                var copy = key
                transform(&copy)
                return copy
            }
        })
    }

    func insertingKey(_ key: KeyDefinition, at position: GridPosition) -> KeyboardLayout {
        guard !rows.isEmpty else { return withRows([[key]]) }
        let r = min(max(position.row, 0), rows.count - 1)
        var newRows = rows
        let i = min(max(position.index, 0), newRows[r].count)
        newRows[r].insert(key, at: i)
        return withRows(newRows)
    }

    func movingKey(_ id: UUID, to position: GridPosition) -> KeyboardLayout {
        guard let key = rows.flatMap({ $0 }).first(where: { $0.id == id }) else { return self }
        return removingKey(id).insertingKey(key, at: position)
    }
}
