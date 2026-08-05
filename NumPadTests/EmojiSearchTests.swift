import XCTest
@testable import NumPad

final class EmojiSearchTests: XCTestCase {
    private func data(
        _ annotations: [[String: Any]],
        cldrVersion: String = "40",
        locale: String = "en"
    ) throws -> Data {
        try JSONSerialization.data(withJSONObject: [
            "cldrVersion": cldrVersion,
            "locale": locale,
            "annotations": annotations,
        ], options: [.sortedKeys])
    }

    private func annotation(
        _ catalogIndex: Int,
        _ name: String,
        _ keywords: [String] = []
    ) -> [String: Any] {
        ["catalogIndex": catalogIndex, "name": name, "keywords": keywords]
    }

    func testNormalizesCaseWidthDiacriticsAndWhitespaceWithPOSIXLocale() throws {
        let index = try EmojiSearchIndex(data: data([
            annotation(0, "Café   gesture"),
            annotation(1, "plain face"),
        ]), catalogCount: 2)

        XCTAssertEqual(index.results(for: "  ＣＡＦＥ gesture  "), [0])
        XCTAssertEqual(index.results(for: "cafe"), [0])
        XCTAssertEqual(index.results(for: "PLAIN"), [1])
        XCTAssertEqual(index.results(for: "   "), [])
    }

    func testRanksExactNameThenNameTokenPrefixThenKeywordInCatalogOrder() throws {
        let index = try EmojiSearchIndex(data: data([
            annotation(4, "party face"),
            annotation(2, "festival", ["party"]),
            annotation(1, "party"),
            annotation(3, "face partygoer"),
            annotation(0, "celebration", ["party"]),
        ]), catalogCount: 5)

        XCTAssertEqual(index.results(for: "party"), [1, 3, 4, 0, 2])
        XCTAssertEqual(index.accessibilityLabel(for: 1), "party")
        XCTAssertEqual(index.accessibilityLabel(for: 4), "party face")
        XCTAssertNil(index.accessibilityLabel(for: -1))
        XCTAssertNil(index.accessibilityLabel(for: 5))
    }

    func testResultLimitIsClampedToTen() throws {
        let annotations = (0..<12).map { annotation($0, "item \($0)", ["match"]) }
        let index = try EmojiSearchIndex(data: data(annotations), catalogCount: 12)

        XCTAssertEqual(index.results(for: "match", limit: 100), Array(0..<10))
        XCTAssertEqual(index.results(for: "match", limit: 3), [0, 1, 2])
        XCTAssertEqual(index.results(for: "match", limit: 0), [])
        XCTAssertEqual(index.results(for: "match", limit: -1), [])
        XCTAssertEqual(index.allResults(for: "match"), Array(0..<12))
        XCTAssertEqual(index.allResults(for: "   "), [])
    }

    func testRejectsInvalidAndDuplicateCatalogIndices() throws {
        XCTAssertThrowsError(try EmojiSearchIndex(data: data([]), catalogCount: 0))
        XCTAssertThrowsError(try EmojiSearchIndex(data: data([]), catalogCount: -1))
        XCTAssertThrowsError(try EmojiSearchIndex(data: data([
            annotation(-1, "negative"),
        ]), catalogCount: 1))
        XCTAssertThrowsError(try EmojiSearchIndex(data: data([
            annotation(1, "past end"),
        ]), catalogCount: 1))
        XCTAssertThrowsError(try EmojiSearchIndex(data: data([
            annotation(0, "first"),
            annotation(0, "duplicate"),
        ]), catalogCount: 1))
        XCTAssertThrowsError(try EmojiSearchIndex(data: data([
            annotation(0, "incomplete"),
        ]), catalogCount: 2))
    }

    func testRejectsEmptyMetadataAndNames() throws {
        XCTAssertThrowsError(try EmojiSearchIndex(
            data: data([annotation(0, "name")], cldrVersion: ""),
            catalogCount: 1
        ))
        XCTAssertThrowsError(try EmojiSearchIndex(
            data: data([annotation(0, "name")], locale: ""),
            catalogCount: 1
        ))
        XCTAssertThrowsError(try EmojiSearchIndex(
            data: data([annotation(0, "")]),
            catalogCount: 1
        ))
    }

    func testLocaleSelectionUsesExactThenLanguageThenPinnedEnglishFallback() {
        XCTAssertEqual(
            EmojiSearchResourceSelection.localeIdentifier(
                preferred: ["fr-CA"],
                available: ["fr-CA", "fr", "en"]
            ),
            "fr-CA"
        )
        XCTAssertEqual(
            EmojiSearchResourceSelection.localeIdentifier(
                preferred: ["fr-CA"],
                available: ["fr", "en"]
            ),
            "fr"
        )
        XCTAssertEqual(
            EmojiSearchResourceSelection.localeIdentifier(
                preferred: ["es-MX"],
                available: ["en"]
            ),
            "en"
        )
        XCTAssertNil(
            EmojiSearchResourceSelection.localeIdentifier(
                preferred: ["es-MX"],
                available: ["de"]
            )
        )
    }

    func testBundledEnglishIndexDecodesAndSearchesByNameAndKeyword() throws {
        let url = try XCTUnwrap(
            Bundle.main.url(forResource: "emoji_search_en_cldr40", withExtension: "json")
        )
        let data = try Data(contentsOf: url)
        let index = try EmojiSearchIndex(data: data, catalogCount: 3_624)

        XCTAssertEqual(index.results(for: "grinning face").first, 0)
        XCTAssertFalse(index.results(for: "wave").isEmpty)
        XCTAssertLessThanOrEqual(index.results(for: "face").count, 10)
    }
}
