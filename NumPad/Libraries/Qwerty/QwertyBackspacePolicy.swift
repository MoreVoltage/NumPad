import Foundation

struct QwertyBackspaceInteractionConfiguration: Equatable {
    let wordDeleteEnabled: Bool
    let initialDelay: TimeInterval
    let repeatInterval: TimeInterval

    init(wordDeleteEnabled: Bool,
         initialDelay: TimeInterval,
         repeatInterval: TimeInterval) {
        self.wordDeleteEnabled = wordDeleteEnabled
        self.initialDelay = initialDelay
        self.repeatInterval = repeatInterval
    }
}

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

    static func action(elapsed: TimeInterval,
                       configuration: QwertyBackspaceInteractionConfiguration) -> Action {
        if elapsed < configuration.initialDelay { return .wait }
        if configuration.wordDeleteEnabled, elapsed >= wordDeleteAfter { return .deleteWord }
        return .deleteCharacter
    }

    static func nextInterval(elapsed: TimeInterval,
                             configuration: QwertyBackspaceInteractionConfiguration) -> TimeInterval {
        if elapsed < configuration.initialDelay {
            return configuration.initialDelay - elapsed
        }
        if elapsed >= accelerationAfter { return acceleratedInterval }
        return configuration.repeatInterval
    }

    static func action(elapsed: TimeInterval, wordDeleteEnabled: Bool) -> Action {
        action(elapsed: elapsed,
               configuration: QwertyBackspaceInteractionConfiguration(
                wordDeleteEnabled: wordDeleteEnabled,
                initialDelay: initialDelay,
                repeatInterval: characterInterval
               ))
    }

    static func nextInterval(elapsed: TimeInterval) -> TimeInterval {
        nextInterval(elapsed: elapsed,
                     configuration: QwertyBackspaceInteractionConfiguration(
                        wordDeleteEnabled: true,
                        initialDelay: initialDelay,
                        repeatInterval: characterInterval
                     ))
    }
}
