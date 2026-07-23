import Foundation

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

    static func increment(_ event: Event, defaults: UserDefaults = .group, by amount: Int = 1) {
        var bag = load(defaults: defaults)
        bag[event.rawValue, default: 0] += amount
        defaults.set(bag, forKey: storageKey)
    }

    static func drain(defaults: UserDefaults = .group) -> [String: Int] {
        let bag = load(defaults: defaults)
        defaults.removeObject(forKey: storageKey)
        return bag
    }

    private static func load(defaults: UserDefaults) -> [String: Int] {
        (defaults.dictionary(forKey: storageKey) as? [String: Int]) ?? [:]
    }
}

