import Foundation

/// Privacy-safe typing counters shared across app + Keyboard extension.
/// Read-modify-write and drain use snapshot-subtract so concurrent writers cannot lose counts,
/// and failed analytics delivery can restore undrained amounts.
enum TypingQualityCounters {
    enum Event: String, CaseIterable {
        case keyTaps
        case suggestionsShown
        case suggestionsAccepted
        case correctionsApplied
        case correctionReverts
        case backspaceTaps
        case backspaceRepeatSessions
        case pageSwitches
        case shortAbandonedSessions
    }

    private static let storageKey = "typingQualityCounters"
    private static let lock = NSLock()

    static func increment(_ event: Event, defaults: UserDefaults = .group, by amount: Int = 1) {
        guard amount != 0 else { return }
        lock.lock(); defer { lock.unlock() }
        var bag = load(defaults: defaults)
        bag[event.rawValue, default: 0] += amount
        defaults.set(bag, forKey: storageKey)
    }

    /// Snapshot current counters and subtract exactly those amounts (like LockFunnelCounters).
    /// Callers must only drop the snapshot after successful analytics delivery; on failure call
    /// `restore(_:defaults:)`.
    static func snapshotAndSubtract(defaults: UserDefaults = .group) -> [String: Int] {
        lock.lock(); defer { lock.unlock() }
        let bag = load(defaults: defaults)
        guard !bag.isEmpty else { return [:] }
        var remaining = bag
        for (key, value) in bag {
            let next = value
            if next <= 0 {
                remaining.removeValue(forKey: key)
            } else {
                remaining.removeValue(forKey: key)
            }
        }
        // Subtract the snapshotted amounts; concurrent increments after load are preserved
        // because we re-load and subtract rather than wiping.
        var current = load(defaults: defaults)
        for (key, value) in bag {
            let next = (current[key] ?? 0) - value
            if next > 0 {
                current[key] = next
            } else {
                current.removeValue(forKey: key)
            }
        }
        if current.isEmpty {
            defaults.removeObject(forKey: storageKey)
        } else {
            defaults.set(current, forKey: storageKey)
        }
        return bag.filter { $0.value > 0 }
    }

    /// Restore counters after a failed flush so counts are not lost.
    static func restore(_ snapshot: [String: Int], defaults: UserDefaults = .group) {
        guard !snapshot.isEmpty else { return }
        lock.lock(); defer { lock.unlock() }
        var bag = load(defaults: defaults)
        for (key, value) in snapshot where value > 0 {
            bag[key, default: 0] += value
        }
        defaults.set(bag, forKey: storageKey)
    }

    /// Legacy drain kept for tests that expect clear-on-read — prefer snapshotAndSubtract in
    /// production so failed delivery can restore.
    static func drain(defaults: UserDefaults = .group) -> [String: Int] {
        snapshotAndSubtract(defaults: defaults)
    }

    static func flushIfNeeded(defaults: UserDefaults = .group,
                              log: (_ name: String, _ attributes: [String: Any]) -> Void = { name, attrs in
                                  Analytics.logEvent(name: name, attributes: attrs)
                              }) {
        let snapshot = snapshotAndSubtract(defaults: defaults)
        guard !snapshot.isEmpty else { return }
        var attributes: [String: Any] = [:]
        for (key, value) in snapshot where value > 0 {
            attributes[key] = value
        }
        guard !attributes.isEmpty else { return }
        // Analytics.logEvent does not surface delivery failure; treat as best-effort success.
        // If a future logger throws/returns false, call restore(snapshot).
        log("typing_quality", attributes)
    }

    private static func load(defaults: UserDefaults) -> [String: Int] {
        (defaults.dictionary(forKey: storageKey) as? [String: Int]) ?? [:]
    }
}
