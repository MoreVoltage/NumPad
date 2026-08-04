//
//  EmojiCatalog.swift
//  NumPad
//

import Foundation

enum EmojiCategory: String, CaseIterable, Codable {
    case smileys
    case people
    case animals
    case food
    case travel
    case activities
    case objects
    case symbols
    case flags
}

struct EmojiCatalogEntry: Codable, Equatable {
    let sequence: String
    let category: EmojiCategory
    let variantIndices: [Int]
}

struct EmojiBrowsePayload: Codable, Equatable {
    let unicodeVersion: String
    let entries: [EmojiCatalogEntry]
}

enum EmojiCatalogError: Error, Equatable {
    case emptyUnicodeVersion
    case emptyCatalog
    case emptySequence(index: Int)
    case duplicateSequence(String)
    case invalidVariantIndex(entry: Int, variant: Int)
    case selfReferentialVariantIndex(entry: Int)
    case duplicateVariantIndex(entry: Int, variant: Int)
}

struct EmojiCatalog: Equatable {
    let unicodeVersion: String
    let entries: [EmojiCatalogEntry]

    init(data: Data) throws {
        let payload = try JSONDecoder().decode(EmojiBrowsePayload.self, from: data)
        try Self.validate(payload)
        unicodeVersion = payload.unicodeVersion
        entries = payload.entries
    }

    func contains(sequence: String) -> Bool {
        entries.contains { $0.sequence == sequence }
    }

    private static func validate(_ payload: EmojiBrowsePayload) throws {
        guard !payload.unicodeVersion.isEmpty else {
            throw EmojiCatalogError.emptyUnicodeVersion
        }
        guard !payload.entries.isEmpty else {
            throw EmojiCatalogError.emptyCatalog
        }

        var sequences = Set<String>()
        for (index, entry) in payload.entries.enumerated() {
            guard !entry.sequence.isEmpty else {
                throw EmojiCatalogError.emptySequence(index: index)
            }
            guard sequences.insert(entry.sequence).inserted else {
                throw EmojiCatalogError.duplicateSequence(entry.sequence)
            }

            var variants = Set<Int>()
            for variant in entry.variantIndices {
                guard payload.entries.indices.contains(variant) else {
                    throw EmojiCatalogError.invalidVariantIndex(entry: index, variant: variant)
                }
                guard variant != index else {
                    throw EmojiCatalogError.selfReferentialVariantIndex(entry: index)
                }
                guard variants.insert(variant).inserted else {
                    throw EmojiCatalogError.duplicateVariantIndex(entry: index, variant: variant)
                }
            }
        }
    }
}
