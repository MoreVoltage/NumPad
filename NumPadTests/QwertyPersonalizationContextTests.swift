import XCTest
@testable import NumPad

final class QwertyPersonalizationContextTests: XCTestCase {
    func test_phoneAutomaticIsolatedFromPadSplit() {
        let phone = QwertyPersonalizationContext.phoneAutomatic
        let pad = QwertyPersonalizationContext(deviceClass: .pad, layoutMode: .split)
        XCTAssertNotEqual(phone, pad)
    }

    func testLegacyBlobMigratesOnceToPhoneAutomaticOnly() {
        var legacy = QwertyTouchPersonalization()
        for _ in 0..<QwertyTouchPersonalization.warmupSamples {
            legacy.recordAcceptedTap(
                keyCharacter: "a",
                normalizedOffset: (dx: 0.25, dy: -0.1)
            )
        }

        let migrated = QwertyTouchPersonalizationEnvelope(data: legacy.encoded())
        XCTAssertEqual(migrated.loadState, .legacy)
        XCTAssertTrue(migrated.requiresMigrationWrite)
        XCTAssertNotNil(migrated.model(for: .phoneAutomatic).offset(forKeyCharacter: "a"))
        XCTAssertNil(
            migrated.model(
                for: QwertyPersonalizationContext(deviceClass: .pad, layoutMode: .centered)
            ).offset(forKeyCharacter: "a"),
            "legacy phone data must never influence an iPad context"
        )

        let decodedAgain = QwertyTouchPersonalizationEnvelope(data: migrated.encoded())
        XCTAssertEqual(decodedAgain.loadState, .current)
        XCTAssertFalse(decodedAgain.requiresMigrationWrite)
        XCTAssertNotNil(decodedAgain.model(for: .phoneAutomatic).offset(forKeyCharacter: "a"))
    }

    func testEnvelopePersistsIndependentModelsByResolvedContext() throws {
        let phone = QwertyPersonalizationContext.phoneAutomatic
        let pad = QwertyPersonalizationContext(deviceClass: .pad, layoutMode: .split)
        var phoneModel = QwertyTouchPersonalization()
        var padModel = QwertyTouchPersonalization()
        for _ in 0..<QwertyTouchPersonalization.warmupSamples {
            phoneModel.recordAcceptedTap(
                keyCharacter: "a",
                normalizedOffset: (dx: 0.3, dy: 0)
            )
            padModel.recordAcceptedTap(
                keyCharacter: "a",
                normalizedOffset: (dx: -0.4, dy: 0)
            )
        }

        var envelope = QwertyTouchPersonalizationEnvelope()
        envelope.setModel(phoneModel, for: phone)
        envelope.setModel(padModel, for: pad)
        let restored = QwertyTouchPersonalizationEnvelope(data: envelope.encoded())

        let phoneOffset = try XCTUnwrap(
            restored.model(for: phone).offset(forKeyCharacter: "a")
        )
        let padOffset = try XCTUnwrap(
            restored.model(for: pad).offset(forKeyCharacter: "a")
        )
        XCTAssertEqual(phoneOffset.dx, 0.3, accuracy: 0.000_001)
        XCTAssertEqual(padOffset.dx, -0.4, accuracy: 0.000_001)
    }

    func testGuardedLegacyMigrationDropsStaleDataWhenResetGenerationChanges() {
        var legacy = QwertyTouchPersonalization()
        legacy.recordAcceptedTap(
            keyCharacter: "a",
            normalizedOffset: (dx: 0.25, dy: 0)
        )
        let migration = QwertyTouchPersonalizationEnvelope(data: legacy.encoded())
        var persisted: Data?

        let result = QwertyTouchPersonalizationPersistence.persistLegacyMigrationIfCurrent(
            envelope: migration,
            loadedGeneration: 7,
            currentGeneration: { 8 },
            currentData: { Data() },
            persist: { persisted = $0 }
        )

        XCTAssertNil(persisted, "a reset that lands after activation must win without a write")
        XCTAssertEqual(result.generation, 8)
        XCTAssertEqual(result.envelope.loadState, .empty)
        XCTAssertNil(result.envelope.model(for: .phoneAutomatic).offset(forKeyCharacter: "a"))
    }

    func testConsistentSnapshotRetriesWhenResetLandsBetweenDictionaryAndGenerationReads() {
        var staleDictionary = QwertyPersonalDictionary()
        for _ in 0..<QwertyPersonalDictionary.protectionThreshold {
            staleDictionary.recordAcceptance(of: "stale")
        }
        var generation = 7
        var dictionaryData = staleDictionary.encoded()
        var touchData = Data()
        var dictionaryReads = 0

        let snapshot = QwertyTouchPersonalizationPersistence.loadConsistentSnapshot(
            currentGeneration: { generation },
            currentDictionaryData: {
                defer { dictionaryReads += 1 }
                let data = dictionaryData
                if dictionaryReads == 0 {
                    // The app reset lands after activation read the old dictionary but before
                    // activation's confirming generation read.
                    dictionaryData = Data()
                    touchData = Data()
                    generation = 8
                }
                return data
            },
            currentTouchData: { touchData }
        )

        XCTAssertEqual(dictionaryReads, 2, "mixed-generation data must be discarded and retried")
        XCTAssertEqual(snapshot.generation, 8)
        XCTAssertFalse(snapshot.dictionary.isKnown("stale"))
        XCTAssertEqual(snapshot.touchEnvelope.loadState, .empty)
    }

    func testMigrationGenerationChangeReloadsBothStoresBeforeAcceptingGeneration() {
        var staleDictionary = QwertyPersonalDictionary()
        for _ in 0..<QwertyPersonalDictionary.protectionThreshold {
            staleDictionary.recordAcceptance(of: "stale")
        }
        var legacyTouch = QwertyTouchPersonalization()
        legacyTouch.recordAcceptedTap(
            keyCharacter: "a",
            normalizedOffset: (dx: 0.25, dy: 0)
        )
        let loaded = QwertyTouchPersonalizationPersistence.Snapshot(
            dictionary: staleDictionary,
            touchEnvelope: QwertyTouchPersonalizationEnvelope(data: legacyTouch.encoded()),
            generation: 7
        )
        var persistedTouch: Data?

        let reloaded = QwertyTouchPersonalizationPersistence.persistLegacyMigrationIfCurrent(
            snapshot: loaded,
            currentGeneration: { 8 },
            currentDictionaryData: { Data() },
            currentTouchData: { Data() },
            persistTouchData: { persistedTouch = $0 }
        )

        XCTAssertNil(persistedTouch, "migration must not write after observing a reset")
        XCTAssertEqual(reloaded.generation, 8)
        XCTAssertFalse(reloaded.dictionary.isKnown("stale"))
        XCTAssertEqual(reloaded.touchEnvelope.loadState, .empty)

        var nextWrite = reloaded.dictionary
        nextWrite.recordAcceptance(of: "fresh")
        let restored = QwertyPersonalDictionary(data: nextWrite.encoded())
        XCTAssertEqual(restored.boost(for: "stale"), 0,
                       "stale pre-reset words must not influence the next dictionary write")
        XCTAssertEqual(restored.boost(for: "fresh"), 1)
    }

    func testCorruptAndUnsupportedFutureEnvelopeAreDistinct() {
        let corrupt = Data("not-json".utf8)
        let future = Data(
            #"{"version":2,"models":{"pad/split":{"offsets":{}}}}"#.utf8
        )

        let corruptEnvelope = QwertyTouchPersonalizationEnvelope(data: corrupt)
        XCTAssertEqual(corruptEnvelope.loadState, .corrupt)
        XCTAssertTrue(corruptEnvelope.permitsPersistence)

        let futureEnvelope = QwertyTouchPersonalizationEnvelope(data: future)
        XCTAssertEqual(futureEnvelope.loadState, .unsupportedVersion(2))
        XCTAssertFalse(futureEnvelope.permitsPersistence)
        XCTAssertEqual(futureEnvelope.encoded(), future)
        XCTAssertEqual(
            futureEnvelope.model(
                for: QwertyPersonalizationContext(deviceClass: .pad, layoutMode: .split)
            ),
            QwertyTouchPersonalization(),
            "unsupported data must fail closed for the active context"
        )
    }

    func testFutureEnvelopeRejectsProductionLearningWriteAndPreservesBytes() {
        let future = Data(#"{"version":42,"models":{}}"#.utf8)
        var envelope = QwertyTouchPersonalizationEnvelope(data: future)
        var learned = QwertyTouchPersonalization()
        learned.recordAcceptedTap(
            keyCharacter: "q",
            normalizedOffset: (dx: 0.2, dy: 0)
        )

        XCTAssertFalse(
            envelope.setModel(
                learned,
                for: QwertyPersonalizationContext(deviceClass: .pad, layoutMode: .centered)
            ),
            "the production host must be able to guard its persistence write"
        )
        XCTAssertEqual(envelope.encoded(), future)
    }
}
