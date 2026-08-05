//
//  EmojiSearch.swift
//  NumPad
//

import Foundation

struct EmojiSearchAnnotation: Codable, Equatable {
    let catalogIndex: Int
    let name: String
    let keywords: [String]
}

struct EmojiSearchPayload: Codable, Equatable {
    let cldrVersion: String
    let locale: String
    let annotations: [EmojiSearchAnnotation]
}

enum EmojiSearchError: Error, Equatable {
    case invalidCatalogCount(Int)
    case emptyCLDRVersion
    case emptyLocale
    case emptyName(catalogIndex: Int)
    case invalidCatalogIndex(Int)
    case duplicateCatalogIndex(Int)
    case incompleteCatalog(expected: Int, actual: Int)
}

struct EmojiSearchIndex {
    private struct IndexedAnnotation {
        let catalogIndex: Int
        let name: String
        let accessibilityName: String
        let nameTokens: [String]
        let keywords: [(value: String, tokens: [String])]
    }

    private let annotations: [IndexedAnnotation]
    private let labelsByCatalogIndex: [String]

    init(data: Data, catalogCount: Int) throws {
        guard catalogCount > 0 else {
            throw EmojiSearchError.invalidCatalogCount(catalogCount)
        }
        let payload = try JSONDecoder().decode(EmojiSearchPayload.self, from: data)
        guard !payload.cldrVersion.isEmpty else { throw EmojiSearchError.emptyCLDRVersion }
        guard !payload.locale.isEmpty else { throw EmojiSearchError.emptyLocale }

        var seenIndices = Set<Int>()
        var indexed: [IndexedAnnotation] = []
        indexed.reserveCapacity(payload.annotations.count)
        for annotation in payload.annotations {
            guard (0..<catalogCount).contains(annotation.catalogIndex) else {
                throw EmojiSearchError.invalidCatalogIndex(annotation.catalogIndex)
            }
            guard seenIndices.insert(annotation.catalogIndex).inserted else {
                throw EmojiSearchError.duplicateCatalogIndex(annotation.catalogIndex)
            }

            let name = Self.normalize(annotation.name)
            guard !name.isEmpty else {
                throw EmojiSearchError.emptyName(catalogIndex: annotation.catalogIndex)
            }
            indexed.append(IndexedAnnotation(
                catalogIndex: annotation.catalogIndex,
                name: name,
                accessibilityName: annotation.name.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ),
                nameTokens: Self.tokens(in: name),
                keywords: annotation.keywords.compactMap { keyword in
                    let value = Self.normalize(keyword)
                    guard !value.isEmpty else { return nil }
                    return (value, Self.tokens(in: value))
                }
            ))
        }

        guard indexed.count == catalogCount else {
            throw EmojiSearchError.incompleteCatalog(
                expected: catalogCount,
                actual: indexed.count
            )
        }
        annotations = indexed
        labelsByCatalogIndex = indexed
            .sorted { $0.catalogIndex < $1.catalogIndex }
            .map(\.accessibilityName)
    }

    func results(for query: String, limit: Int = 10) -> [Int] {
        let boundedLimit = min(max(limit, 0), 10)
        guard boundedLimit > 0 else { return [] }
        return Array(rankedResults(for: query).prefix(boundedLimit))
    }

    /// Full deterministic result set for the browse-grid filter. The top-strip API above
    /// remains independently capped at ten and cannot be widened by this read-only seam.
    func allResults(for query: String) -> [Int] {
        rankedResults(for: query)
    }

    private func rankedResults(for query: String) -> [Int] {
        let normalizedQuery = Self.normalize(query)
        guard !normalizedQuery.isEmpty else { return [] }

        return annotations.compactMap { annotation -> (rank: Int, catalogIndex: Int)? in
            if annotation.name == normalizedQuery {
                return (0, annotation.catalogIndex)
            }
            if annotation.name.hasPrefix(normalizedQuery)
                || annotation.nameTokens.contains(where: { $0.hasPrefix(normalizedQuery) }) {
                return (1, annotation.catalogIndex)
            }
            if annotation.keywords.contains(where: { keyword in
                keyword.value == normalizedQuery
                    || keyword.value.hasPrefix(normalizedQuery)
                    || keyword.tokens.contains(where: { $0.hasPrefix(normalizedQuery) })
            }) {
                return (2, annotation.catalogIndex)
            }
            return nil
        }
        .sorted {
            if $0.rank != $1.rank { return $0.rank < $1.rank }
            return $0.catalogIndex < $1.catalogIndex
        }
        .map(\.catalogIndex)
    }

    /// English CLDR TTS label for an exact catalog index. Search ranking and result shape stay
    /// independent from accessibility lookup so callers cannot accidentally personalize or
    /// reorder results while asking VoiceOver for a name.
    func accessibilityLabel(for catalogIndex: Int) -> String? {
        guard labelsByCatalogIndex.indices.contains(catalogIndex) else { return nil }
        return labelsByCatalogIndex[catalogIndex]
    }

    private static let posixLocale = Locale(identifier: "en_US_POSIX")

    private static func normalize(_ value: String) -> String {
        value
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                locale: posixLocale
            )
            .lowercased(with: posixLocale)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    private static func tokens(in value: String) -> [String] {
        value.split { !$0.isLetter && !$0.isNumber }.map(String.init)
    }
}

enum EmojiSearchResourceSelection {
    static func localeIdentifier(
        preferred: [String],
        available: Set<String>
    ) -> String? {
        let orderedAvailable = available.sorted()

        for identifier in preferred {
            let normalized = normalizeIdentifier(identifier)
            if let exact = orderedAvailable.first(where: {
                normalizeIdentifier($0) == normalized
            }) {
                return exact
            }

            let language = normalized.split(separator: "-").first.map(String.init) ?? normalized
            if let languageMatch = orderedAvailable.first(where: {
                normalizeIdentifier($0) == language
            }) {
                return languageMatch
            }
        }

        return orderedAvailable.first(where: { normalizeIdentifier($0) == "en" })
    }

    private static func normalizeIdentifier(_ identifier: String) -> String {
        identifier.replacingOccurrences(of: "_", with: "-").lowercased()
    }
}
