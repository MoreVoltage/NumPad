import Foundation

/// Persists the active custom keyboard config in a `UserDefaults` (the app passes the shared
/// app-group suite; tests pass a throwaway suite). `onChange` runs after any mutation — the app
/// wires it to `SettingsSync.post()` so a live keyboard extension re-reads immediately.
///
/// One config today: the key holds a single encoded `CustomKeyboardConfig`. Multiple keyboards can
/// be layered on later (encode an array + an active id) without disturbing callers.
struct CustomKeyboardStore {
    let defaults: UserDefaults
    var key: String = Constants.customKeyboardConfig.rawValue
    var onChange: () -> Void = {}

    func load() -> CustomKeyboardConfig? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(CustomKeyboardConfig.self, from: data)
    }

    func save(_ config: CustomKeyboardConfig) {
        if let data = try? JSONEncoder().encode(config) {
            defaults.set(data, forKey: key)
        }
        onChange()
    }

    func clear() {
        defaults.removeObject(forKey: key)
        onChange()
    }
}
