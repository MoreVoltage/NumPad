import Foundation
import XCTest
@testable import NumPad

final class EmojiResourceLoaderTests: XCTestCase {
    private final class LockedCounter {
        private let lock = NSLock()
        private var storage = 0

        var value: Int {
            lock.lock()
            defer { lock.unlock() }
            return storage
        }

        func increment() {
            lock.lock()
            storage += 1
            lock.unlock()
        }
    }

    private func browseData() -> Data {
        Data(
            """
            {
              "unicodeVersion": "14.0",
              "entries": [
                {"sequence": "😀", "category": "smileys", "variantIndices": []},
                {"sequence": "👋", "category": "people", "variantIndices": []}
              ]
            }
            """.utf8
        )
    }

    private func searchData() -> Data {
        Data(
            """
            {
              "cldrVersion": "40",
              "locale": "en",
              "annotations": [
                {"catalogIndex": 0, "name": "grinning face", "keywords": ["smile"]},
                {"catalogIndex": 1, "name": "waving hand", "keywords": ["wave"]}
              ]
            }
            """.utf8
        )
    }

    func testInitializationInvokesNoFactoriesAndRetainsNoRawBuffers() {
        let browseCalls = LockedCounter()
        let searchCalls = LockedCounter()
        let loader = EmojiResourceLoader(
            browseDataFactory: {
                browseCalls.increment()
                return self.browseData()
            },
            searchDataFactory: {
                searchCalls.increment()
                return self.searchData()
            }
        )

        XCTAssertFalse(loader.hasLoadedBrowse)
        XCTAssertFalse(loader.hasLoadedSearch)
        XCTAssertEqual(loader.retainedRawDataByteCount, 0)
        XCTAssertEqual(browseCalls.value, 0)
        XCTAssertEqual(searchCalls.value, 0)
    }

    func testBrowseAndSearchLoadInSeparateStagesAndReuseParsedCaches() async throws {
        let browseCalls = LockedCounter()
        let searchCalls = LockedCounter()
        let loader = EmojiResourceLoader(
            browseDataFactory: {
                browseCalls.increment()
                return self.browseData()
            },
            searchDataFactory: {
                searchCalls.increment()
                return self.searchData()
            }
        )

        let firstBrowse = try await loader.loadBrowse()
        let secondBrowse = try await loader.loadBrowse()
        XCTAssertEqual(firstBrowse, secondBrowse)
        XCTAssertTrue(loader.hasLoadedBrowse)
        XCTAssertFalse(loader.hasLoadedSearch)
        XCTAssertEqual(browseCalls.value, 1)
        XCTAssertEqual(searchCalls.value, 0)
        XCTAssertEqual(loader.retainedRawDataByteCount, 0)

        let firstSearch = try await loader.loadEnglishSearch(catalogCount: 2)
        let secondSearch = try await loader.loadEnglishSearch(catalogCount: 2)
        XCTAssertEqual(firstSearch.results(for: "wave"), [1])
        XCTAssertEqual(secondSearch.accessibilityLabel(for: 0), "grinning face")
        XCTAssertTrue(loader.hasLoadedBrowse)
        XCTAssertTrue(loader.hasLoadedSearch)
        XCTAssertEqual(browseCalls.value, 1)
        XCTAssertEqual(searchCalls.value, 1)
        XCTAssertEqual(loader.retainedRawDataByteCount, 0)
    }

    func testFactoryErrorsFailClosedWithoutLeavingLoadedStateOrBuffers() async {
        let loader = EmojiResourceLoader(
            browseDataFactory: {
                throw EmojiResourceLoaderError.missingResource("emoji_browse_v14.json")
            },
            searchDataFactory: {
                throw EmojiResourceLoaderError.missingResource("emoji_search_en_cldr40.json")
            }
        )

        do {
            _ = try await loader.loadBrowse()
            XCTFail("missing browse resource must throw")
        } catch {
            XCTAssertEqual(
                error as? EmojiResourceLoaderError,
                .missingResource("emoji_browse_v14.json")
            )
        }
        XCTAssertFalse(loader.hasLoadedBrowse)
        XCTAssertEqual(loader.retainedRawDataByteCount, 0)

        do {
            _ = try await loader.loadEnglishSearch(catalogCount: 2)
            XCTFail("missing search resource must throw")
        } catch {
            XCTAssertEqual(
                error as? EmojiResourceLoaderError,
                .missingResource("emoji_search_en_cldr40.json")
            )
        }
        XCTAssertFalse(loader.hasLoadedSearch)
        XCTAssertEqual(loader.retainedRawDataByteCount, 0)
    }

    func testMemoryWarningKeepsBrowseOnlyWhenEmojiIsActiveAndDropsEverythingWhenInactive() async throws {
        let browseCalls = LockedCounter()
        let searchCalls = LockedCounter()
        let loader = EmojiResourceLoader(
            browseDataFactory: {
                browseCalls.increment()
                return self.browseData()
            },
            searchDataFactory: {
                searchCalls.increment()
                return self.searchData()
            }
        )

        _ = try await loader.loadBrowse()
        _ = try await loader.loadEnglishSearch(catalogCount: 2)
        loader.handleMemoryWarning(isEmojiActive: true)
        XCTAssertTrue(loader.hasLoadedBrowse)
        XCTAssertFalse(loader.hasLoadedSearch)

        _ = try await loader.loadEnglishSearch(catalogCount: 2)
        XCTAssertEqual(searchCalls.value, 2)
        loader.handleMemoryWarning(isEmojiActive: false)
        XCTAssertFalse(loader.hasLoadedBrowse)
        XCTAssertFalse(loader.hasLoadedSearch)

        _ = try await loader.loadBrowse()
        XCTAssertEqual(browseCalls.value, 2)
        XCTAssertEqual(loader.retainedRawDataByteCount, 0)
    }
}
