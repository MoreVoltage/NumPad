import XCTest
@testable import NumPad

final class EmojiRecentsTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "emoji-recents-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testLoadFiltersUnknownAndDuplicateSequencesPreservingNewestOrder() {
        let valid: Set<String> = ["😀", "👋"]
        let recents = EmojiRecents(
            raw: ["😀", "unknown", "👋", "😀"],
            isValid: valid.contains
        )

        XCTAssertEqual(recents.sequences, ["😀", "👋"])
    }

    func testRecordMovesExistingExactSequenceToFront() {
        let valid: Set<String> = ["😀", "👋", "🎉"]
        var recents = EmojiRecents(
            raw: ["😀", "👋", "🎉"],
            isValid: valid.contains
        )

        recents.record("👋", isValid: valid.contains)

        XCTAssertEqual(recents.sequences, ["👋", "😀", "🎉"])
    }

    func testBaseAndSkinToneVariantRemainDistinctExactSequences() {
        let valid: Set<String> = ["👋", "👋🏻"]
        var recents = EmojiRecents(raw: [], isValid: valid.contains)

        recents.record("👋", isValid: valid.contains)
        recents.record("👋🏻", isValid: valid.contains)

        XCTAssertEqual(recents.sequences, ["👋🏻", "👋"])
    }

    func testCapacityTrimsLoadAndNewRecordToFortyEight() {
        let raw = (0..<60).map { "emoji-\($0)" }
        var recents = EmojiRecents(raw: raw, isValid: { _ in true })

        XCTAssertEqual(EmojiRecents.capacity, 48)
        XCTAssertEqual(recents.sequences, Array(raw.prefix(48)))

        recents.record(raw[59], isValid: { _ in true })
        XCTAssertEqual(recents.sequences.count, 48)
        XCTAssertEqual(recents.sequences.first, raw[59])
        XCTAssertEqual(Array(recents.sequences.dropFirst()), Array(raw.prefix(47)))
    }

    func testMalformedAndInvalidRecordsAreIgnored() {
        var recents = EmojiRecents(raw: ["", "😀"], isValid: { _ in true })

        XCTAssertEqual(recents.sequences, ["😀"])
        recents.record("", isValid: { _ in true })
        recents.record("unknown", isValid: { $0 == "😀" })

        XCTAssertEqual(recents.sequences, ["😀"])
    }

    func testStoreRoundTripsFlatSequenceArrayUnderConstantsKeyOnly() {
        let key = Constants.qwertyEmojiRecents.rawValue
        let store = EmojiRecentsStore(defaults: defaults)
        let recents = EmojiRecents(raw: ["😀", "👋🏻"], isValid: { _ in true })

        store.save(recents)

        XCTAssertEqual(defaults.stringArray(forKey: key), ["😀", "👋🏻"])
        let persistentKeys = defaults
            .persistentDomain(forName: suiteName)
            .map { Set($0.keys) } ?? []
        XCTAssertEqual(
            persistentKeys,
            Set([key]),
            "V1 persists no timestamps, analytics fields, or companion metadata"
        )
        XCTAssertEqual(
            store.load(isValid: { ["😀", "👋🏻"].contains($0) }),
            recents
        )
    }

    func testCorruptDefaultsFallBackToEmpty() {
        let key = Constants.qwertyEmojiRecents.rawValue
        let store = EmojiRecentsStore(defaults: defaults)

        defaults.set("not an array", forKey: key)
        XCTAssertEqual(store.load(isValid: { _ in true }).sequences, [])

        defaults.set(["😀", 42] as [Any], forKey: key)
        XCTAssertEqual(store.load(isValid: { _ in true }).sequences, [])
    }
}
