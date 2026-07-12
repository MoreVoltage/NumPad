import XCTest
@testable import NumPad

final class QwertyPersonalDictionaryTests: XCTestCase {

    // MARK: counting

    func testRecordingAcceptanceCounts() {
        var dictionary = QwertyPersonalDictionary()
        dictionary.recordAcceptance(of: "numpad")
        dictionary.recordAcceptance(of: "numpad")
        XCTAssertEqual(dictionary.boost(for: "numpad"), 2)
    }

    func testRecordingLowercasesAndLookupIsCaseInsensitive() {
        var dictionary = QwertyPersonalDictionary()
        dictionary.recordAcceptance(of: "NumPad")
        XCTAssertEqual(dictionary.counts, ["numpad": 1])
        XCTAssertEqual(dictionary.boost(for: "NUMPAD"), 1)
    }

    func testBoostIsZeroForAbsentWord() {
        XCTAssertEqual(QwertyPersonalDictionary().boost(for: "anything"), 0)
    }

    func testWordBecomesKnownAtProtectionThreshold() {
        var dictionary = QwertyPersonalDictionary()
        for _ in 0..<(QwertyPersonalDictionary.protectionThreshold - 1) {
            dictionary.recordAcceptance(of: "fjord")
        }
        XCTAssertFalse(dictionary.isKnown("fjord"))
        dictionary.recordAcceptance(of: "fjord")
        XCTAssertTrue(dictionary.isKnown("Fjord"), "known-word lookup is case-insensitive")
    }

    // MARK: input hygiene — letters/'/- only, length 2–24

    func testAcceptsContractionsAndHyphenatedCompounds() {
        var dictionary = QwertyPersonalDictionary()
        dictionary.recordAcceptance(of: "don't")
        dictionary.recordAcceptance(of: "well-known")
        dictionary.recordAcceptance(of: "don\u{2019}t")  // curly apostrophe (smart punctuation)
        XCTAssertEqual(dictionary.boost(for: "don't"), 1)
        XCTAssertEqual(dictionary.boost(for: "well-known"), 1)
        XCTAssertEqual(dictionary.boost(for: "don\u{2019}t"), 1)
    }

    func testIgnoresNumbersSingleLettersAndJunk() {
        var dictionary = QwertyPersonalDictionary()
        let junk = ["", "a",                              // too short
                    String(repeating: "a", count: 25),    // too long
                    "1234", "teh1",                       // numbers
                    "he!lo", "word.", "two words",        // punctuation / whitespace
                    "--", "''"]                           // no letters at all
        for word in junk { dictionary.recordAcceptance(of: word) }
        XCTAssertEqual(dictionary, QwertyPersonalDictionary(),
                       "junk neither counts nor advances the decay clock")
    }

    func testTwentyFourLettersIsTheLongestAcceptedWord() {
        var dictionary = QwertyPersonalDictionary()
        let word = String(repeating: "a", count: 24)
        dictionary.recordAcceptance(of: word)
        XCTAssertEqual(dictionary.boost(for: word), 1)
    }

    // MARK: decay — halve everything, drop zeros, every decayInterval recordings

    func testDecayHalvesCountsAndDropsZeros() {
        var dictionary = QwertyPersonalDictionary()
        for _ in 0..<4 { dictionary.recordAcceptance(of: "numpad") }
        // Fill the rest of the decay window with one-off words.
        for index in 0..<(QwertyPersonalDictionary.decayInterval - 4) {
            dictionary.recordAcceptance(of: filler(index))
        }
        XCTAssertEqual(dictionary.boost(for: "numpad"), 2, "4 halves to 2")
        XCTAssertEqual(dictionary.counts.count, 1, "count-1 words halve to zero and drop")
        XCTAssertEqual(dictionary.recordingsSinceDecay, 0, "the decay clock resets")
    }

    func testDecayClockAdvancesOnlyOnValidRecordings() {
        var dictionary = QwertyPersonalDictionary()
        dictionary.recordAcceptance(of: "hello")
        dictionary.recordAcceptance(of: "123")
        XCTAssertEqual(dictionary.recordingsSinceDecay, 1)
    }

    // MARK: eviction — a full dictionary drops its weakest entry for a newcomer

    func testEvictionRemovesLowestCountEntryAtCapacity() {
        var counts: [String: Int] = [:]
        for index in 0..<QwertyPersonalDictionary.capacity {
            counts[filler(index)] = index == 7 ? 1 : 5  // unique minimum at index 7
        }
        var dictionary = seeded(counts: counts)
        dictionary.recordAcceptance(of: "newcomer")
        XCTAssertEqual(dictionary.counts.count, QwertyPersonalDictionary.capacity)
        XCTAssertNil(dictionary.counts[filler(7)], "the lowest-count entry is evicted")
        XCTAssertEqual(dictionary.boost(for: "newcomer"), 1)
    }

    func testReRecordingAnExistingWordAtCapacityEvictsNothing() {
        var counts: [String: Int] = [:]
        for index in 0..<QwertyPersonalDictionary.capacity {
            counts[filler(index)] = index == 7 ? 1 : 5
        }
        var dictionary = seeded(counts: counts)
        dictionary.recordAcceptance(of: filler(0))
        XCTAssertEqual(dictionary.counts.count, QwertyPersonalDictionary.capacity)
        XCTAssertEqual(dictionary.boost(for: filler(7)), 1, "nothing was evicted")
        XCTAssertEqual(dictionary.boost(for: filler(0)), 6)
    }

    // MARK: persistence — Codable round-trips, corrupt data degrades to empty

    func testCodableRoundTrip() throws {
        var original = QwertyPersonalDictionary()
        for _ in 0..<3 { original.recordAcceptance(of: "numpad") }
        original.recordAcceptance(of: "fjord")
        let decoded = try JSONDecoder().decode(QwertyPersonalDictionary.self,
                                               from: JSONEncoder().encode(original))
        XCTAssertEqual(decoded, original)
    }

    func testStorageEncodingRoundTrip() {
        var original = QwertyPersonalDictionary()
        original.recordAcceptance(of: "hello")
        XCTAssertEqual(QwertyPersonalDictionary(data: original.encoded()), original)
    }

    func testCorruptOrEmptyDataDegradesToEmptyDictionary() {
        XCTAssertEqual(QwertyPersonalDictionary(data: Data()), QwertyPersonalDictionary())
        XCTAssertEqual(QwertyPersonalDictionary(data: Data("not json".utf8)),
                       QwertyPersonalDictionary())
    }

    // MARK: helpers

    /// Letter-only filler words ("xxaaa", "xxaab", …) — digits would be rejected by the
    /// hygiene filter, so indexes are spelled in base-26.
    private func filler(_ index: Int) -> String {
        let letters = Array("abcdefghijklmnopqrstuvwxyz")
        return "xx\(letters[(index / 676) % 26])\(letters[(index / 26) % 26])\(letters[index % 26])"
    }

    /// Builds a dictionary with explicit counts through the storage seam (the synthesized
    /// Codable keys), so eviction can be tested without 7,500 recordAcceptance calls.
    private func seeded(counts: [String: Int]) -> QwertyPersonalDictionary {
        let object: [String: Any] = ["counts": counts, "recordingsSinceDecay": 0]
        let data = try! JSONSerialization.data(withJSONObject: object)
        return QwertyPersonalDictionary(data: data)
    }
}
