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
            snapshot: QwertyTouchPersonalizationPersistence.Snapshot(
                dictionary: QwertyPersonalDictionary(),
                touchEnvelope: migration,
                generation: 6
            ),
            currentEpoch: { 8 },
            currentDictionaryData: { Data() },
            currentTouchData: { Data() },
            persistTouchData: { persisted = $0 }
        )

        XCTAssertNil(persisted, "a reset that lands after activation must win without a write")
        XCTAssertEqual(result.generation, 8)
        XCTAssertEqual(result.touchEnvelope.loadState, .empty)
        XCTAssertNil(
            result.touchEnvelope
                .model(for: .phoneAutomatic)
                .offset(forKeyCharacter: "a")
        )
    }

    func testSuccessfulGuardedMigrationReturnsThePersistedCurrentEnvelope() {
        var legacy = QwertyTouchPersonalization()
        legacy.recordAcceptedTap(
            keyCharacter: "a",
            normalizedOffset: (dx: 0.25, dy: 0)
        )
        let loaded = QwertyTouchPersonalizationPersistence.Snapshot(
            dictionary: QwertyPersonalDictionary(),
            touchEnvelope: QwertyTouchPersonalizationEnvelope(data: legacy.encoded()),
            generation: 0,
            dictionaryStoreState: .empty,
            touchStoreState: .legacy
        )
        var touchData = legacy.encoded()

        let result = QwertyTouchPersonalizationPersistence.persistLegacyMigrationIfCurrent(
            snapshot: loaded,
            currentEpoch: { 0 },
            currentDictionaryData: { Data() },
            currentTouchData: { touchData },
            persistTouchData: { touchData = $0 }
        )

        XCTAssertEqual(result.touchEnvelope.loadState, .current)
        XCTAssertFalse(result.touchEnvelope.requiresMigrationWrite)
        let reloaded = QwertyTouchPersonalizationPersistence.loadConsistentSnapshot(
            currentEpoch: { 0 },
            currentDictionaryData: { Data() },
            currentTouchData: { touchData }
        )
        XCTAssertEqual(reloaded, result)
    }

    func testConsistentSnapshotRejectsMixedStoresWhileLegacyGenerationStillLooksStable() {
        var staleDictionary = QwertyPersonalDictionary()
        for _ in 0..<QwertyPersonalDictionary.protectionThreshold {
            staleDictionary.recordAcceptance(of: "stale")
        }
        var staleTouch = QwertyTouchPersonalization()
        for _ in 0..<QwertyTouchPersonalization.warmupSamples {
            staleTouch.recordAcceptedTap(
                keyCharacter: "a",
                normalizedOffset: (dx: 0.25, dy: 0)
            )
        }
        var epoch = 0
        var legacyGeneration = 41
        var dictionaryData = staleDictionary.encoded()
        var touchData = staleTouch.encoded()
        var dictionaryReads = 0
        var epochReads = 0
        var legacyGenerationObservedAroundStores: [Int] = []

        let snapshot = QwertyTouchPersonalizationPersistence.loadConsistentSnapshot(
            currentEpoch: {
                defer { epochReads += 1 }
                if epochReads == 1 {
                    // The legacy protocol still looks unchanged on both sides of the mixed
                    // store reads. The new epoch is already odd, so the attempt must fail.
                    legacyGenerationObservedAroundStores.append(legacyGeneration)
                    let observed = epoch
                    legacyGeneration += 1
                    epoch = 2
                    return observed
                }
                return epoch
            },
            currentDictionaryData: {
                defer { dictionaryReads += 1 }
                let data = dictionaryData
                if dictionaryReads == 0 {
                    legacyGenerationObservedAroundStores.append(legacyGeneration)
                    // Reset starts after the first epoch read. Its in-progress epoch becomes
                    // visible before either learned store is cleared.
                    epoch = 1
                    dictionaryData = Data()
                }
                return data
            },
            currentTouchData: {
                let data = touchData
                touchData = Data()
                return data
            }
        )

        XCTAssertEqual(dictionaryReads, 2, "mixed-generation data must be discarded and retried")
        XCTAssertEqual(legacyGenerationObservedAroundStores, [41, 41],
                       "the old counter cannot expose an in-progress reset")
        XCTAssertEqual(snapshot.generation, 2)
        XCTAssertFalse(snapshot.dictionary.isKnown("stale"))
        XCTAssertEqual(snapshot.touchEnvelope.loadState, .empty)
    }

    func testMigrationWriteOverlappingResetCannotRestoreStaleDictionaryOrTouchData() {
        var staleDictionary = QwertyPersonalDictionary()
        for _ in 0..<QwertyPersonalDictionary.protectionThreshold {
            staleDictionary.recordAcceptance(of: "stale")
        }
        var legacyTouch = QwertyTouchPersonalization()
        for _ in 0..<QwertyTouchPersonalization.warmupSamples {
            legacyTouch.recordAcceptedTap(
                keyCharacter: "a",
                normalizedOffset: (dx: 0.25, dy: 0)
            )
        }
        let loaded = QwertyTouchPersonalizationPersistence.Snapshot(
            dictionary: staleDictionary,
            touchEnvelope: QwertyTouchPersonalizationEnvelope(data: legacyTouch.encoded()),
            generation: 0
        )
        var epoch = 0
        var dictionaryData = staleDictionary.encoded()
        var touchData = legacyTouch.encoded()

        let reloaded = QwertyTouchPersonalizationPersistence.persistLegacyMigrationIfCurrent(
            snapshot: loaded,
            currentEpoch: { epoch },
            currentDictionaryData: { dictionaryData },
            currentTouchData: { touchData },
            persistTouchData: { migratedData in
                // Migration passed its pre-write check. Reset then brackets and clears both
                // stores before this delayed migration write lands.
                epoch = 1
                dictionaryData = Data()
                touchData = Data()
                epoch = 2
                touchData = migratedData
            }
        )

        XCTAssertFalse(touchData.isEmpty, "precondition: the delayed stale write physically landed")
        XCTAssertEqual(reloaded.generation, 2)
        XCTAssertFalse(reloaded.dictionary.isKnown("stale"))
        XCTAssertEqual(reloaded.touchEnvelope.loadState, .empty)

        var freshDictionary = reloaded.dictionary
        freshDictionary.recordAcceptance(of: "fresh")
        let afterDictionaryWrite = QwertyTouchPersonalizationPersistence
            .persistDictionaryIfCurrent(
                snapshot: reloaded,
                updatedDictionary: freshDictionary,
                currentEpoch: { epoch },
                currentDictionaryData: { dictionaryData },
                currentTouchData: { touchData },
                persistDictionaryData: { dictionaryData = $0 }
            )
        var freshTouch = afterDictionaryWrite.touchEnvelope
        var freshModel = QwertyTouchPersonalization()
        for _ in 0..<QwertyTouchPersonalization.warmupSamples {
            freshModel.recordAcceptedTap(
                keyCharacter: "b",
                normalizedOffset: (dx: -0.2, dy: 0)
            )
        }
        XCTAssertTrue(freshTouch.setModel(freshModel, for: .phoneAutomatic))
        let afterTouchWrite = QwertyTouchPersonalizationPersistence.persistTouchIfCurrent(
            snapshot: afterDictionaryWrite,
            updatedEnvelope: freshTouch,
            currentEpoch: { epoch },
            currentDictionaryData: { dictionaryData },
            currentTouchData: { touchData },
            persistTouchData: { touchData = $0 }
        )

        XCTAssertEqual(afterTouchWrite.dictionary.boost(for: "stale"), 0)
        XCTAssertEqual(afterTouchWrite.dictionary.boost(for: "fresh"), 1)
        XCTAssertNil(
            afterTouchWrite.touchEnvelope
                .model(for: .phoneAutomatic)
                .offset(forKeyCharacter: "a"),
            "the stale migrated offset must not seed the next persisted envelope"
        )
        XCTAssertNotNil(
            afterTouchWrite.touchEnvelope
                .model(for: .phoneAutomatic)
                .offset(forKeyCharacter: "b")
        )
    }

    func testResetBracketsBothStoreClearsWithOddThenEvenEpoch() {
        var epoch = 4
        var legacyGeneration = 12
        var dictionaryData = Data([0x01])
        var touchData = Data([0x02])
        var events: [String] = []

        QwertyTouchPersonalizationPersistence.resetAll(
            currentEpoch: { epoch },
            setEpoch: {
                epoch = $0
                events.append("epoch:\($0)")
            },
            clearDictionary: {
                XCTAssertEqual(epoch, 5)
                dictionaryData = Data()
                events.append("dictionary")
            },
            clearTouch: {
                XCTAssertEqual(epoch, 5)
                touchData = Data()
                events.append("touch")
            },
            incrementLegacyGeneration: {
                XCTAssertEqual(epoch, 5)
                legacyGeneration += 1
                events.append("legacy")
            }
        )

        XCTAssertEqual(events, ["epoch:5", "dictionary", "touch", "legacy", "epoch:6"])
        XCTAssertEqual(epoch, 6)
        XCTAssertEqual(legacyGeneration, 13)
        XCTAssertTrue(dictionaryData.isEmpty)
        XCTAssertTrue(touchData.isEmpty)
    }

    func testPersistedOddEpochIsRecoveredWithinBoundedReadsWithoutAcceptingStaleData() {
        var staleDictionary = QwertyPersonalDictionary()
        staleDictionary.addExplicit("stale")
        var staleTouch = QwertyTouchPersonalization()
        for _ in 0..<QwertyTouchPersonalization.warmupSamples {
            staleTouch.recordAcceptedTap(
                keyCharacter: "s",
                normalizedOffset: (dx: 0.3, dy: 0)
            )
        }
        var epoch = 5
        var dictionaryData = staleDictionary.encoded()
        var touchData = staleTouch.encoded()
        var epochReads = 0
        var recoveries = 0

        let snapshot = QwertyTouchPersonalizationPersistence.loadConsistentSnapshot(
            currentEpoch: {
                epochReads += 1
                return epoch
            },
            currentDictionaryData: { dictionaryData },
            currentTouchData: { touchData },
            recoverAbandonedEpoch: { abandonedEpoch in
                recoveries += 1
                XCTAssertEqual(abandonedEpoch, 5)
                dictionaryData = Data()
                touchData = Data()
                epoch = 6
            }
        )

        XCTAssertLessThanOrEqual(epochReads, 5, "main-thread recovery must use bounded polling")
        XCTAssertEqual(recoveries, 1)
        XCTAssertEqual(snapshot.generation, 6)
        XCTAssertTrue(snapshot.permitsPersistence)
        XCTAssertFalse(snapshot.dictionary.isKnown("stale"))
        XCTAssertEqual(snapshot.touchEnvelope.loadState, .empty)
    }

    func testResetTakesOwnershipOfPersistedOddEpochWithoutPolling() {
        var epoch = 5
        var epochReads = 0
        var dictionaryData = Data([0x01])
        var touchData = Data([0x02])

        QwertyTouchPersonalizationPersistence.resetAll(
            currentEpoch: {
                epochReads += 1
                return epoch
            },
            setEpoch: { epoch = $0 },
            clearDictionary: { dictionaryData = Data() },
            clearTouch: { touchData = Data() },
            incrementLegacyGeneration: {}
        )

        XCTAssertEqual(epochReads, 1)
        XCTAssertEqual(epoch, 6)
        XCTAssertTrue(dictionaryData.isEmpty)
        XCTAssertTrue(touchData.isEmpty)
    }

    func testAppDictionaryMutationRecoversPersistedOddEpochBeforeWriting() {
        var staleDictionary = QwertyPersonalDictionary()
        staleDictionary.addExplicit("stale")
        var freshDictionary = QwertyPersonalDictionary()
        freshDictionary.addExplicit("fresh")
        var epoch = 5
        var dictionaryData = staleDictionary.encoded()
        var touchData = Data([0x01])
        var recoveries = 0

        let result = QwertyTouchPersonalizationPersistence.replaceDictionary(
            with: freshDictionary,
            currentEpoch: { epoch },
            setEpoch: { epoch = $0 },
            currentDictionaryData: { dictionaryData },
            currentTouchData: { touchData },
            persistDictionaryData: { dictionaryData = $0 },
            persistTouchData: { touchData = $0 },
            incrementLegacyGeneration: {},
            recoverAbandonedEpoch: { abandonedEpoch in
                recoveries += 1
                XCTAssertEqual(abandonedEpoch, 5)
                dictionaryData = Data()
                touchData = Data()
                epoch = 6
            }
        )

        XCTAssertEqual(recoveries, 1)
        XCTAssertEqual(epoch, 8)
        XCTAssertTrue(result.dictionary.isKnown("fresh"))
        XCTAssertFalse(result.dictionary.isKnown("stale"))
        XCTAssertEqual(result.touchEnvelope.loadState, .current)
        XCTAssertEqual(
            result.touchEnvelope.model(for: .phoneAutomatic),
            QwertyTouchPersonalization()
        )
    }

    func testAppDictionaryMutationAdvancesEpochAndPreservesTouchEnvelope() {
        var originalTouch = QwertyTouchPersonalization()
        for _ in 0..<QwertyTouchPersonalization.warmupSamples {
            originalTouch.recordAcceptedTap(
                keyCharacter: "q",
                normalizedOffset: (dx: 0.15, dy: 0)
            )
        }
        var updatedDictionary = QwertyPersonalDictionary()
        updatedDictionary.addExplicit("NumPad")
        var epoch = 0
        var legacyGeneration = 7
        var dictionaryData = Data()
        var touchData = originalTouch.encoded()

        let result = QwertyTouchPersonalizationPersistence.replaceDictionary(
            with: updatedDictionary,
            currentEpoch: { epoch },
            setEpoch: { epoch = $0 },
            currentDictionaryData: { dictionaryData },
            currentTouchData: { touchData },
            persistDictionaryData: { dictionaryData = $0 },
            persistTouchData: { touchData = $0 },
            incrementLegacyGeneration: { legacyGeneration += 1 }
        )

        XCTAssertEqual(epoch, 2)
        XCTAssertEqual(legacyGeneration, 8)
        XCTAssertTrue(result.dictionary.isKnown("numpad"))
        XCTAssertNotNil(
            result.touchEnvelope
                .model(for: .phoneAutomatic)
                .offset(forKeyCharacter: "q")
        )
        let reloaded = QwertyTouchPersonalizationPersistence.loadConsistentSnapshot(
            currentEpoch: { epoch },
            currentDictionaryData: { dictionaryData },
            currentTouchData: { touchData }
        )
        XCTAssertEqual(reloaded, result)
    }

    func testFutureOuterDictionaryPayloadPreservesBytesAndRejectsAllWrites() {
        var staleDictionary = QwertyPersonalDictionary()
        staleDictionary.addExplicit("stale")
        let futureOuter = futureOuterPayload(
            version: 42,
            generation: 0,
            payload: staleDictionary.encoded()
        )
        var dictionaryData = futureOuter
        var touchData = Data()
        let snapshot = QwertyTouchPersonalizationPersistence.loadConsistentSnapshot(
            currentEpoch: { 0 },
            currentDictionaryData: { dictionaryData },
            currentTouchData: { touchData }
        )

        XCTAssertEqual(snapshot.dictionaryStoreState, .unsupportedVersion(42))
        XCTAssertFalse(snapshot.permitsPersistence)
        XCTAssertFalse(snapshot.dictionary.isKnown("stale"))

        var updatedDictionary = snapshot.dictionary
        updatedDictionary.addExplicit("fresh")
        _ = QwertyTouchPersonalizationPersistence.persistDictionaryIfCurrent(
            snapshot: snapshot,
            updatedDictionary: updatedDictionary,
            currentEpoch: { 0 },
            currentDictionaryData: { dictionaryData },
            currentTouchData: { touchData },
            persistDictionaryData: { dictionaryData = $0 }
        )
        var updatedTouch = snapshot.touchEnvelope
        updatedTouch.setModel(QwertyTouchPersonalization(), for: .phoneAutomatic)
        _ = QwertyTouchPersonalizationPersistence.persistTouchIfCurrent(
            snapshot: snapshot,
            updatedEnvelope: updatedTouch,
            currentEpoch: { 0 },
            currentDictionaryData: { dictionaryData },
            currentTouchData: { touchData },
            persistTouchData: { touchData = $0 }
        )

        XCTAssertEqual(dictionaryData, futureOuter)
        XCTAssertTrue(touchData.isEmpty)
    }

    func testFutureOuterTouchPayloadPreservesBytesAndRejectsMigrationAndLearningWrites() {
        var legacyTouch = QwertyTouchPersonalization()
        legacyTouch.recordAcceptedTap(
            keyCharacter: "a",
            normalizedOffset: (dx: 0.2, dy: 0)
        )
        let futureOuter = futureOuterPayload(
            version: 99,
            generation: 0,
            payload: legacyTouch.encoded()
        )
        var dictionaryData = Data()
        var touchData = futureOuter
        let snapshot = QwertyTouchPersonalizationPersistence.loadConsistentSnapshot(
            currentEpoch: { 0 },
            currentDictionaryData: { dictionaryData },
            currentTouchData: { touchData }
        )

        XCTAssertEqual(snapshot.touchStoreState, .unsupportedVersion(99))
        XCTAssertFalse(snapshot.permitsPersistence)
        XCTAssertEqual(snapshot.touchEnvelope.loadState, .empty)

        _ = QwertyTouchPersonalizationPersistence.persistLegacyMigrationIfCurrent(
            snapshot: snapshot,
            currentEpoch: { 0 },
            currentDictionaryData: { dictionaryData },
            currentTouchData: { touchData },
            persistTouchData: { touchData = $0 }
        )
        var updatedTouch = snapshot.touchEnvelope
        updatedTouch.setModel(QwertyTouchPersonalization(), for: .phoneAutomatic)
        _ = QwertyTouchPersonalizationPersistence.persistTouchIfCurrent(
            snapshot: snapshot,
            updatedEnvelope: updatedTouch,
            currentEpoch: { 0 },
            currentDictionaryData: { dictionaryData },
            currentTouchData: { touchData },
            persistTouchData: { touchData = $0 }
        )
        var updatedDictionary = snapshot.dictionary
        updatedDictionary.addExplicit("fresh")
        _ = QwertyTouchPersonalizationPersistence.persistDictionaryIfCurrent(
            snapshot: snapshot,
            updatedDictionary: updatedDictionary,
            currentEpoch: { 0 },
            currentDictionaryData: { dictionaryData },
            currentTouchData: { touchData },
            persistDictionaryData: { dictionaryData = $0 }
        )

        XCTAssertEqual(touchData, futureOuter)
        XCTAssertTrue(dictionaryData.isEmpty)
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

    private func futureOuterPayload(
        version: Int,
        generation: Int,
        payload: Data
    ) -> Data {
        Data(
            """
            {"marker":"numpad-qwerty-personalization","version":\(version),"generation":\(generation),"payload":"\(payload.base64EncodedString())"}
            """.utf8
        )
    }
}
