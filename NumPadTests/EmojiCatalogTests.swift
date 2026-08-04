import XCTest
@testable import NumPad

final class EmojiCatalogTests: XCTestCase {
    private func data(_ json: String) -> Data {
        Data(json.utf8)
    }

    func testDecodesOrderedCatalogAndExactSequenceMembership() throws {
        let catalog = try EmojiCatalog(data: data(
            """
            {
              "unicodeVersion": "14.0",
              "entries": [
                {"sequence": "😀", "category": "smileys", "variantIndices": []},
                {"sequence": "👋", "category": "people", "variantIndices": [2]},
                {"sequence": "👋🏻", "category": "people", "variantIndices": []}
              ]
            }
            """
        ))

        XCTAssertEqual(catalog.unicodeVersion, "14.0")
        XCTAssertEqual(catalog.entries.map(\.sequence), ["😀", "👋", "👋🏻"])
        XCTAssertEqual(catalog.entries[1].variantIndices, [2])
        XCTAssertTrue(catalog.contains(sequence: "👋🏻"))
        XCTAssertFalse(catalog.contains(sequence: "👋🏿"))
    }

    func testRejectsDuplicateSequences() {
        XCTAssertThrowsError(try EmojiCatalog(data: data(
            """
            {
              "unicodeVersion": "14.0",
              "entries": [
                {"sequence": "😀", "category": "smileys", "variantIndices": []},
                {"sequence": "😀", "category": "smileys", "variantIndices": []}
              ]
            }
            """
        )))
    }

    func testRejectsOutOfRangeAndSelfReferentialVariantIndices() {
        let outOfRange =
            """
            {
              "unicodeVersion": "14.0",
              "entries": [
                {"sequence": "👋", "category": "people", "variantIndices": [1]}
              ]
            }
            """
        XCTAssertThrowsError(try EmojiCatalog(data: data(outOfRange)))

        let selfReference =
            """
            {
              "unicodeVersion": "14.0",
              "entries": [
                {"sequence": "👋", "category": "people", "variantIndices": [0]}
              ]
            }
            """
        XCTAssertThrowsError(try EmojiCatalog(data: data(selfReference)))
    }

    func testRejectsEmptyVersionCatalogAndSequence() {
        XCTAssertThrowsError(try EmojiCatalog(data: data(
            """
            {"unicodeVersion": "", "entries": []}
            """
        )))
        XCTAssertThrowsError(try EmojiCatalog(data: data(
            """
            {
              "unicodeVersion": "14.0",
              "entries": [
                {"sequence": "", "category": "symbols", "variantIndices": []}
              ]
            }
            """
        )))
    }

    func testEveryApprovedCategoryDecodes() throws {
        let categories = EmojiCategory.allCases
        XCTAssertEqual(categories.map(\.rawValue), [
            "smileys", "people", "animals", "food", "travel",
            "activities", "objects", "symbols", "flags",
        ])
    }

    func testBundledCatalogIsPinnedRGIOnlyAndWithinResourceBudget() throws {
        let browseURL = try XCTUnwrap(
            Bundle.main.url(forResource: "emoji_browse_v14", withExtension: "json")
        )
        let searchURL = try XCTUnwrap(
            Bundle.main.url(forResource: "emoji_search_en_cldr40", withExtension: "json")
        )
        let licenseURL = try XCTUnwrap(
            Bundle.main.url(forResource: "emoji-unicode-license", withExtension: "txt")
        )

        let browseData = try Data(contentsOf: browseURL)
        let searchData = try Data(contentsOf: searchURL)
        let license = try String(contentsOf: licenseURL, encoding: .utf8)
        let catalog = try EmojiCatalog(data: browseData)

        XCTAssertEqual(catalog.unicodeVersion, "14.0")
        XCTAssertGreaterThan(catalog.entries.count, 3_000)
        XCTAssertEqual(catalog.entries.prefix(4).map(\.sequence), ["😀", "😃", "😄", "😁"])
        XCTAssertEqual(catalog.entries.first?.category, .smileys)
        XCTAssertTrue(catalog.contains(sequence: "😀"))
        XCTAssertTrue(catalog.contains(sequence: "👋🏻"))
        XCTAssertTrue(catalog.contains(sequence: "☺️"))
        XCTAssertFalse(catalog.contains(sequence: "☺"), "unqualified form must not be shipped")
        XCTAssertLessThanOrEqual(browseData.count, 1_048_576)
        XCTAssertLessThanOrEqual(searchData.count, 1_048_576)
        XCTAssertTrue(license.contains("UNICODE LICENSE V3"))

        let wavingIndex = try XCTUnwrap(catalog.entries.firstIndex { $0.sequence == "👋" })
        XCTAssertEqual(
            catalog.entries[wavingIndex].variantIndices.map { catalog.entries[$0].sequence },
            ["👋🏻", "👋🏼", "👋🏽", "👋🏾", "👋🏿"]
        )

        for (index, entry) in catalog.entries.enumerated() {
            XCTAssertFalse(entry.sequence.isEmpty, "empty sequence at index \(index)")
            XCTAssertFalse(entry.variantIndices.contains(index), "self variant at index \(index)")
            XCTAssertTrue(entry.variantIndices.allSatisfy(catalog.entries.indices.contains))
        }
    }
}
