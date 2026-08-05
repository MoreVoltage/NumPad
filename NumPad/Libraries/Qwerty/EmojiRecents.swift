//
//  EmojiRecents.swift
//  NumPad
//

import Foundation

struct EmojiRecents: Equatable {
    static let capacity = 48

    private(set) var sequences: [String]

    init(raw: [String], isValid: (String) -> Bool) {
        var seen = Set<String>()
        var sanitized: [String] = []
        sanitized.reserveCapacity(min(raw.count, Self.capacity))

        for sequence in raw {
            guard sanitized.count < Self.capacity else { break }
            guard !sequence.isEmpty,
                  isValid(sequence),
                  seen.insert(sequence).inserted else { continue }
            sanitized.append(sequence)
        }

        sequences = sanitized
    }

    mutating func record(
        _ sequence: String,
        isValid: (String) -> Bool
    ) {
        guard !sequence.isEmpty, isValid(sequence) else { return }

        sequences.removeAll { $0 == sequence }
        sequences.insert(sequence, at: 0)
        if sequences.count > Self.capacity {
            sequences.removeLast(sequences.count - Self.capacity)
        }
    }
}

struct EmojiRecentsStore {
    private let defaults: UserDefaults
    private let key: String

    init(
        defaults: UserDefaults = .group,
        key: String = Constants.qwertyEmojiRecents.rawValue
    ) {
        self.defaults = defaults
        self.key = key
    }

    func load(isValid: (String) -> Bool) -> EmojiRecents {
        guard let raw = defaults.object(forKey: key) as? [String] else {
            return EmojiRecents(raw: [], isValid: isValid)
        }
        return EmojiRecents(raw: raw, isValid: isValid)
    }

    func save(_ recents: EmojiRecents) {
        defaults.set(recents.sequences, forKey: key)
    }
}
