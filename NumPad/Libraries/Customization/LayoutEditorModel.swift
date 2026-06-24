import Foundation
import Combine

/// The view-model the SwiftUI editor binds to. A thin shell over `LayoutStore` (persistence) and the
/// pure `KeyboardLayout` editing ops. iOS 16 → `ObservableObject` (not `@Observable`, which is iOS 17).
final class LayoutEditorModel: ObservableObject {
    @Published private(set) var layouts: [KeyboardLayout]
    @Published private(set) var activeID: UUID?
    private let store: LayoutStore

    init(store: LayoutStore) {
        self.store = store
        self.layouts = store.loadLayouts()
        self.activeID = store.activeID
    }

    /// Creates a new layout seeded from the standard numpad, appends it, persists, and returns it.
    @discardableResult
    func createLayout(named name: String) -> KeyboardLayout {
        let seed = KeyboardLayout.standard
        let layout = KeyboardLayout(name: name, rows: seed.rows, keyScale: seed.keyScale)
        layouts.append(layout)
        store.saveLayouts(layouts)
        return layout
    }

    func activate(_ id: UUID?) {
        activeID = id
        store.setActiveID(id)
    }

    /// Guarantees exactly one canonical layout exists and is active, returning its id. Seeds from
    /// `KeyboardLayout.standard` on first use. Idempotent — never creates a second layout. The 2.0
    /// editor surfaces only this one layout (the multi-layout list is retained but unsurfaced).
    @discardableResult
    func ensurePrimaryLayout() -> KeyboardLayout.ID {
        if let existing = activeID ?? layouts.first?.id {
            if activeID == nil { activate(existing) }
            return existing
        }
        let created = createLayout(named: KeyboardLayout.standard.name)
        activate(created.id)
        return created.id
    }

    func rename(_ id: UUID, to name: String) {
        layouts = layouts.map { layout in
            guard layout.id == id else { return layout }
            return KeyboardLayout(id: layout.id, name: name, rows: layout.rows,
                                  keyScale: layout.keyScale, schemaVersion: layout.schemaVersion)
        }
        store.saveLayouts(layouts)
    }

    func delete(_ id: UUID) {
        layouts.removeAll { $0.id == id }
        if activeID == id { activate(nil) }
        store.saveLayouts(layouts)
    }

    /// Applies a pure editing op (insert/remove/move/update) to a stored layout and persists.
    func updateLayout(_ id: UUID, _ transform: (KeyboardLayout) -> KeyboardLayout) {
        layouts = layouts.map { $0.id == id ? transform($0) : $0 }
        store.saveLayouts(layouts)
    }
}
