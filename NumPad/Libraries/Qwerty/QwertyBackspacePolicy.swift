import Foundation

enum QwertyBackspacePolicy {
    enum Action: Equatable {
        case wait
        case deleteCharacter
        case deleteWord
    }

    static let initialDelay: TimeInterval = 0.35
    static let characterInterval: TimeInterval = 0.10
    static let acceleratedInterval: TimeInterval = 0.06
    static let accelerationAfter: TimeInterval = 1.5
    static let wordDeleteAfter: TimeInterval = 2.5

    static func action(elapsed: TimeInterval, wordDeleteEnabled: Bool) -> Action {
        if elapsed < initialDelay { return .wait }
        if wordDeleteEnabled, elapsed >= wordDeleteAfter { return .deleteWord }
        return .deleteCharacter
    }

    static func nextInterval(elapsed: TimeInterval) -> TimeInterval {
        if elapsed < initialDelay { return initialDelay - elapsed }
        if elapsed >= accelerationAfter { return acceleratedInterval }
        return characterInterval
    }
}

