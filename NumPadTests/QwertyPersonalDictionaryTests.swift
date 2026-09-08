import XCTest
@testable import NumPad

final class QwertyPersonalDictionaryTests: XCTestCase {

    func testExplicitWordSurvivesMultipleDecayWindowsAndRoundTrip() {
        var dictionary = QwertyPersonalDictionary()
        XCTAssertTrue(dictionary.addExplicit("Cedarvale"))
        for _ in 0..<(QwertyPersonalDictionary.decayInterval * 3) {
            dictionary.recordAcceptance(of: "ordinary")
        }
        dictionary = QwertyPersonalDictionary(data: dictionary.encoded())
        XCTAssertTrue(dictionary.isKnown("CEDARVALE"))
        XCTAssertTrue(dictionary.explicitWords.contains("cedarvale"))
        XCTAssertTrue(dictionary.remove("Cedarvale"))
        XCTAssertFalse(dictionary.isKnown("cedarvale"))
        XCTAssertFalse(dictionary.explicitWords.contains("cedarvale"))
    }

    func testAdaptiveEvictionPreservesExplicitWord() {
        var counts: [String: Int] = [:]
        for index in 0..<QwertyPersonalDictionary.capacity { counts[filler(index)] = 5 }
        var dictionary = seeded(counts: counts)
        XCTAssertTrue(dictionary.addExplicit(filler(0)))
        XCTAssertTrue(dictionary.recordAcceptance(of: "newcomer"))
        XCTAssertTrue(dictionary.isKnown(filler(0)))
        XCTAssertEqual(dictionary.counts.count, QwertyPersonalDictionary.capacity)
        XCTAssertNil(dictionary.counts[filler(1)])
    }

    func testFullExplicitDictionaryDoesNotSilentlyEvictUserWords() {
        var dictionary = QwertyPersonalDictionary()
        for index in 0..<QwertyPersonalDictionary.capacity {
            XCTAssertTrue(dictionary.addExplicit(filler(index)))
        }
        XCTAssertFalse(dictionary.addExplicit("newcomer"))
        XCTAssertFalse(dictionary.recordAcceptance(of: "newcomer"))
        XCTAssertEqual(dictionary.explicitWords.count, QwertyPersonalDictionary.capacity)
        XCTAssertTrue(dictionary.isKnown(filler(0)))
        XCTAssertTrue(dictionary.remove(filler(0)))
        XCTAssertTrue(dictionary.addExplicit("newcomer"))
    }

    func testLegacyDictionaryKeepsCountsWithoutInventingExplicitEntries() {
        let dictionary = seeded(counts: ["legacy": 7])
        XCTAssertEqual(dictionary.boost(for: "legacy"), 7)
        XCTAssertTrue(dictionary.explicitWords.isEmpty)
        XCTAssertEqual(QwertyPersonalDictionary(data: dictionary.encoded()), dictionary)
    }

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

    func testExplicitAdditionProtectsWordImmediately() {
        var dictionary = QwertyPersonalDictionary()

        XCTAssertTrue(dictionary.addExplicit("NumPad"))
        XCTAssertTrue(dictionary.isKnown("numpad"))
        XCTAssertGreaterThanOrEqual(dictionary.boost(for: "NUMPAD"),
                                    QwertyPersonalDictionary.protectionThreshold)
    }

    // MARK: input hygiene — letters/'/- only, length 2–24

    func testApostropheVariantsFoldToOneEntry() {
        var dictionary = QwertyPersonalDictionary()
        dictionary.recordAcceptance(of: "don't")
        dictionary.recordAcceptance(of: "don\u{2019}t")  // curly apostrophe (smart punctuation)
        dictionary.recordAcceptance(of: "well-known")
        XCTAssertEqual(dictionary.counts["don't"], 2,
                       "straight and curly apostrophes accumulate as ONE entry")
        XCTAssertEqual(dictionary.boost(for: "don\u{2019}t"), 2, "lookup folds too")
        XCTAssertEqual(dictionary.boost(for: "well-known"), 1)
    }

    func testRecordAcceptanceReportsWhetherItRecorded() {
        var dictionary = QwertyPersonalDictionary()
        XCTAssertTrue(dictionary.recordAcceptance(of: "hello"))
        XCTAssertFalse(dictionary.recordAcceptance(of: "123"),
                       "hygiene-rejected words report false so callers can skip persisting")
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
        let fillerCount = QwertyPersonalDictionary.decayInterval - 4
        for index in 0..<fillerCount {
            dictionary.recordAcceptance(of: filler(index))
        }
        XCTAssertEqual(dictionary.boost(for: "numpad"), 2, "4 halves to 2")
        // Decay runs BEFORE the boundary recording, so the word landing exactly on the
        // interval survives at count 1 instead of being halved to zero immediately.
        XCTAssertEqual(dictionary.counts.count, 2,
                       "count-1 words drop; the boundary word itself survives")
        XCTAssertEqual(dictionary.boost(for: filler(fillerCount - 1)), 1)
        XCTAssertEqual(dictionary.recordingsSinceDecay, 0, "the decay clock resets")
    }

    func testDecayFiresExactlyAtTheIntervalBoundary() {
        var dictionary = QwertyPersonalDictionary()
        for _ in 0..<4 { dictionary.recordAcceptance(of: "anchor") }
        for index in 0..<(QwertyPersonalDictionary.decayInterval - 5) {
            dictionary.recordAcceptance(of: filler(index))
        }
        XCTAssertEqual(dictionary.recordingsSinceDecay,
                       QwertyPersonalDictionary.decayInterval - 1)
        XCTAssertEqual(dictionary.boost(for: "anchor"), 4, "one short of the interval: no decay")
        dictionary.recordAcceptance(of: filler(QwertyPersonalDictionary.decayInterval))
        XCTAssertEqual(dictionary.boost(for: "anchor"), 2, "the interval-th recording decays")
    }

    func testProtectionSurvivesUntilDecayThenDrops() {
        // Pins the protection/decay tradeoff explicitly: a name accepted exactly
        // protectionThreshold (3) times stays protected through the decay window, then one
        // halving (3 → 1) drops it below the threshold until it is re-typed.
        var dictionary = QwertyPersonalDictionary()
        for _ in 0..<QwertyPersonalDictionary.protectionThreshold {
            dictionary.recordAcceptance(of: "sarah")
        }
        XCTAssertTrue(dictionary.isKnown("sarah"))
        for index in 0..<(QwertyPersonalDictionary.decayInterval
                            - QwertyPersonalDictionary.protectionThreshold) {
            dictionary.recordAcceptance(of: filler(index))
        }
        XCTAssertEqual(dictionary.boost(for: "sarah"), 1, "3 halves to 1")
        XCTAssertFalse(dictionary.isKnown("sarah"),
                       "one decay window without re-typing forfeits protection")
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

    func testEvictionBreaksCountTiesAlphabetically() {
        var counts: [String: Int] = [:]
        for index in 0..<QwertyPersonalDictionary.capacity {
            counts[filler(index)] = index <= 1 ? 1 : 5  // filler(0)/filler(1) tie at the minimum
        }
        var dictionary = seeded(counts: counts)
        dictionary.recordAcceptance(of: "newcomer")
        XCTAssertNil(dictionary.counts[filler(0)],
                     "equal-minimum ties evict the alphabetically first entry")
        XCTAssertEqual(dictionary.boost(for: filler(1)), 1, "the later tie survives")
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

    // MARK: reset generation (the split-view stale write-back guard lives in QwertyPageHost;
    // the storage default is what the model layer can pin)

    func testResetGenerationDefaultsToZero() {
        UserDefaults.group.removeObject(forKey: Constants.qwertyPersonalResetGeneration.rawValue)
        XCTAssertEqual(UserPrefs.qwertyPersonalResetGeneration, 0)
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
