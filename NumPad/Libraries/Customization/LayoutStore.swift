import Foundation

/// Persists custom layouts + the active selection in a `UserDefaults` (the app passes the shared
/// app-group suite; tests pass a throwaway suite). `onChange` is invoked after any mutation — the
/// app wires it to `SettingsSync.post()` so a live keyboard extension re-reads immediately.
struct LayoutStore {
    let defaults: UserDefaults
    var layoutsKey: String = "customLayouts"
    var activeKey: String = "activeLayoutID"
    var onChange: () -> Void = {}

    func loadLayouts() -> [KeyboardLayout] {
        guard let data = defaults.data(forKey: layoutsKey) else { return [] }
        return (try? JSONDecoder().decode([KeyboardLayout].self, from: data)) ?? []
    }

    func saveLayouts(_ layouts: [KeyboardLayout]) {
        if let data = try? JSONEncoder().encode(layouts) {
            defaults.set(data, forKey: layoutsKey)
        }
        onChange()
    }

    var activeID: UUID? {
        guard let raw = defaults.string(forKey: activeKey) else { return nil }
        return UUID(uuidString: raw)
    }

    func setActiveID(_ id: UUID?) {
        defaults.set(id?.uuidString, forKey: activeKey)
        onChange()
    }

    /// The active layout, `repaired()` so the keyboard always renders a usable grid. Nil when no
    /// active id is set or it no longer matches a stored layout.
    func activeLayout() -> KeyboardLayout? {
        guard let id = activeID else { return nil }
        return loadLayouts().first { $0.id == id }?.repaired()
    }
}
