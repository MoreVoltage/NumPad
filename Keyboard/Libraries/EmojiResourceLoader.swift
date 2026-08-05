//
//  EmojiResourceLoader.swift
//  Keyboard
//

import Foundation

protocol EmojiResourceLoading: AnyObject {
    var hasLoadedBrowse: Bool { get }
    var hasLoadedSearch: Bool { get }

    func loadBrowse() async throws -> EmojiCatalog
    func loadEnglishSearch(catalogCount: Int) async throws -> EmojiSearchIndex
    func handleMemoryWarning(isEmojiActive: Bool)
}

enum EmojiResourceLoaderError: Error, Equatable {
    case missingResource(String)
}

/// Two-stage loader for the extension's pinned emoji resources.
///
/// The factories are intentionally inert until their matching load call. Parsed values are
/// immutable and cached; transient JSON buffers are released before either async method
/// returns. A memory warning keeps only the browse catalog while emoji is visible and drops
/// both stages when it is not.
final class EmojiResourceLoader: EmojiResourceLoading {
    typealias DataFactory = () throws -> Data

    private let browseDataFactory: DataFactory
    private let searchDataFactory: DataFactory
    private let lock = NSLock()
    private var browseCache: EmojiCatalog?
    private var searchCache: (catalogCount: Int, index: EmojiSearchIndex)?
    private var rawDataByteCount = 0
    private var cacheGeneration = 0

    init(
        bundle: Bundle = .main,
        browseDataFactory: DataFactory? = nil,
        searchDataFactory: DataFactory? = nil
    ) {
        self.browseDataFactory = browseDataFactory ?? {
            guard let url = bundle.url(
                forResource: "emoji_browse_v14",
                withExtension: "json"
            ) else {
                throw EmojiResourceLoaderError.missingResource("emoji_browse_v14.json")
            }
            return try Data(contentsOf: url, options: [.mappedIfSafe])
        }
        self.searchDataFactory = searchDataFactory ?? {
            guard let url = bundle.url(
                forResource: "emoji_search_en_cldr40",
                withExtension: "json"
            ) else {
                throw EmojiResourceLoaderError.missingResource("emoji_search_en_cldr40.json")
            }
            return try Data(contentsOf: url, options: [.mappedIfSafe])
        }
    }

    var hasLoadedBrowse: Bool {
        withLock { browseCache != nil }
    }

    var hasLoadedSearch: Bool {
        withLock { searchCache != nil }
    }

    /// Test-visible instrumentation proving JSON bytes do not become retained loader state.
    var retainedRawDataByteCount: Int {
        withLock { rawDataByteCount }
    }

    func loadBrowse() async throws -> EmojiCatalog {
        if let cached = withLock({ browseCache }) { return cached }
        let generation = withLock { cacheGeneration }

        let factory = browseDataFactory
        let decoded = try await Task.detached(priority: .userInitiated) {
            let data = try factory()
            return try EmojiCatalog(data: data)
        }.value

        return withLock {
            rawDataByteCount = 0
            if let cached = browseCache { return cached }
            if cacheGeneration == generation { browseCache = decoded }
            return decoded
        }
    }

    func loadEnglishSearch(catalogCount: Int) async throws -> EmojiSearchIndex {
        if let cached = withLock({ searchCache }), cached.catalogCount == catalogCount {
            return cached.index
        }
        let generation = withLock { cacheGeneration }

        let factory = searchDataFactory
        let decoded = try await Task.detached(priority: .userInitiated) {
            let data = try factory()
            return try EmojiSearchIndex(data: data, catalogCount: catalogCount)
        }.value

        return withLock {
            rawDataByteCount = 0
            if let cached = searchCache, cached.catalogCount == catalogCount {
                return cached.index
            }
            if cacheGeneration == generation { searchCache = (catalogCount, decoded) }
            return decoded
        }
    }

    func handleMemoryWarning(isEmojiActive: Bool) {
        withLock {
            cacheGeneration &+= 1
            searchCache = nil
            rawDataByteCount = 0
            if !isEmojiActive { browseCache = nil }
        }
    }

    @discardableResult
    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}
