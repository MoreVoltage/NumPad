//
//  EmojiKeyboardReducer.swift
//  NumPad
//

import Foundation

enum EmojiKeyboardMode: Equatable {
    case typing
    case browse(category: EmojiCategory, filter: String?)
    case search(query: String)
}

enum EmojiKeyboardAction: Equatable {
    case openEmoji
    case openSearch
    case queryText(String)
    case queryBackspace
    case queryReturn
    case showBrowse
    case selectEmoji(String)
    case browseBackspace
    case showTyping
    case nextKeyboard
    case catalogFailed
    case searchFailed
}

enum EmojiKeyboardEffect: Equatable {
    case loadBrowse
    case loadSearch
    case insertEmoji(String)
    case deleteBackward
    case advanceToNextKeyboard
    case announceUnavailable
    case refreshTypingIfPublic
}

enum EmojiKeyboardReducer {
    static func reduce(
        mode: inout EmojiKeyboardMode,
        action: EmojiKeyboardAction
    ) -> [EmojiKeyboardEffect] {
        switch (mode, action) {
        case (.typing, .openEmoji):
            mode = .browse(category: .smileys, filter: nil)
            return [.loadBrowse]

        case (.browse, .openSearch):
            mode = .search(query: "")
            return [.loadSearch]

        case let (.search(query), .queryText(text)):
            mode = .search(query: query + text)
            return []

        case let (.search(query), .queryBackspace):
            guard !query.isEmpty else { return [] }
            mode = .search(query: String(query.dropLast()))
            return []

        case let (.search(query), .queryReturn),
             let (.search(query), .showBrowse):
            mode = .browse(
                category: .smileys,
                filter: query.isEmpty ? nil : query
            )
            return []

        case let (.browse, .selectEmoji(sequence)),
             let (.search, .selectEmoji(sequence)):
            guard !sequence.isEmpty else { return [] }
            return [.insertEmoji(sequence)]

        case (.browse, .browseBackspace):
            return [.deleteBackward]

        case (.browse, .showTyping), (.search, .showTyping):
            mode = .typing
            return [.refreshTypingIfPublic]

        case (.browse, .nextKeyboard), (.search, .nextKeyboard):
            return [.advanceToNextKeyboard]

        case (.browse, .catalogFailed), (.search, .catalogFailed):
            mode = .typing
            return [.announceUnavailable]

        case (.search, .searchFailed):
            mode = .browse(category: .smileys, filter: nil)
            return [.announceUnavailable]

        default:
            return []
        }
    }
}
