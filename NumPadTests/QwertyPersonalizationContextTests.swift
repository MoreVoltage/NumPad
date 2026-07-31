import XCTest
@testable import NumPad

final class QwertyPersonalizationContextTests: XCTestCase {
    func testIPadCompositionContextsAreStableAndDoNotReuseLegacyOffsets() {
        let standard = QwertyPersonalizationContext.resolved(
            idiom: .pad,
            layout: .standard,
            numpadSide: .right
        )
        let fullLeft = QwertyPersonalizationContext.resolved(
            idiom: .pad,
            layout: .full,
            numpadSide: .left
        )
        let fullRight = QwertyPersonalizationContext.resolved(
            idiom: .pad,
            layout: .full,
            numpadSide: .right
        )
        let legacySplit = QwertyPersonalizationContext(deviceClass: .pad, layoutMode: .split)

        XCTAssertEqual(standard.storageKey, "pad/standard")
        XCTAssertEqual(fullLeft.storageKey, "pad/full-left")
        XCTAssertEqual(fullRight.storageKey, "pad/full-right")
        XCTAssertNotEqual(standard, fullLeft)
        XCTAssertNotEqual(fullLeft, fullRight)

        var legacyModel = QwertyTouchPersonalization()
        for _ in 0..<QwertyTouchPersonalization.warmupSamples {
            legacyModel.recordAcceptedTap(
                keyCharacter: "a",
                normalizedOffset: (dx: 0.25, dy: 0)
            )
        }
        var envelope = QwertyTouchPersonalizationEnvelope()
        envelope.setModel(legacyModel, for: legacySplit)
        XCTAssertNil(envelope.model(for: standard).offset(forKeyCharacter: "a"))
    }

    func testResolvedCompositionContextTracksLiveSidesAndFallbacks() {
        let bounds = CGRect(x: 0, y: 0, width: 1_000, height: 320)
        let standard = QwertyPersonalizationContext.resolved(
            bounds: bounds,
            idiom: .pad,
            horizontalSizeClass: .regular,
            layout: .standard,
            numpadSide: .right,
            isFloating: false
        )
        let fullLeft = QwertyPersonalizationContext.resolved(
            bounds: bounds,
            idiom: .pad,
            horizontalSizeClass: .regular,
            layout: .full,
            numpadSide: .left,
            isFloating: false
        )
        let fullRight = QwertyPersonalizationContext.resolved(
            bounds: bounds,
            idiom: .pad,
            horizontalSizeClass: .regular,
            layout: .full,
            numpadSide: .right,
            isFloating: false
        )
        let compact = QwertyPersonalizationContext.resolved(
            bounds: bounds,
            idiom: .pad,
            horizontalSizeClass: .compact,
            layout: .full,
            numpadSide: .left,
            isFloating: false
        )
        let floating = QwertyPersonalizationContext.resolved(
            bounds: bounds,
            idiom: .pad,
            horizontalSizeClass: .regular,
            layout: .full,
            numpadSide: .left,
            isFloating: true
        )

        XCTAssertEqual(standard.storageKey, "pad/standard")
        XCTAssertEqual(fullLeft.storageKey, "pad/full-left")
        XCTAssertEqual(fullRight.storageKey, "pad/full-right")
        XCTAssertEqual(compact, standard)
        XCTAssertEqual(floating, standard)
    }

    func testCompositionContextEnvelopeKeepsAppliedOffsetsWithTheirLivePane() throws {
        let bounds = CGRect(x: 0, y: 0, width: 1_000, height: 320)
        let left = QwertyPersonalizationContext.resolved(
            bounds: bounds,
            idiom: .pad,
            horizontalSizeClass: .regular,
            layout: .full,
            numpadSide: .left,
            isFloating: false
        )
        let right = QwertyPersonalizationContext.resolved(
            bounds: bounds,
            idiom: .pad,
            horizontalSizeClass: .regular,
            layout: .full,
            numpadSide: .right,
            isFloating: false
        )
        var leftModel = QwertyTouchPersonalization()
        for _ in 0..<QwertyTouchPersonalization.warmupSamples {
            leftModel.recordAcceptedTap(keyCharacter: "a", normalizedOffset: (dx: 0.2, dy: 0))
        }
        var envelope = QwertyTouchPersonalizationEnvelope()
        envelope.setModel(leftModel, for: left)

        XCTAssertNotNil(envelope.model(for: left).offset(forKeyCharacter: "a"))
        XCTAssertNil(envelope.model(for: right).offset(forKeyCharacter: "a"))
        XCTAssertNil(
            envelope.model(for: QwertyPersonalizationContext.resolved(
                bounds: bounds,
                idiom: .pad,
                horizontalSizeClass: .compact,
                layout: .full,
                numpadSide: .left,
                isFloating: false
            )).offset(forKeyCharacter: "a")
        )
    }

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
        XCTAssertTrue(result.writeWasCommitted)
        let reloaded = QwertyTouchPersonalizationPersistence.loadConsistentSnapshot(
            currentEpoch: { 0 },
            currentDictionaryData: { Data() },
            currentTouchData: { touchData }
        )
        XCTAssertEqual(reloaded, result)
    }

    func testReloadedSameEpochSnapshotIsNotReportedAsCommittedWrite() {
        var storedDictionary = QwertyPersonalDictionary()
        storedDictionary.addExplicit("stored")
        var attemptedDictionary = storedDictionary
        attemptedDictionary.addExplicit("attempted")
        let dictionaryData = futureOuterPayload(
            version: 1,
            generation: 2,
            payload: storedDictionary.encoded()
        )
        let loaded = QwertyTouchPersonalizationPersistence.Snapshot(
            dictionary: storedDictionary,
            touchEnvelope: QwertyTouchPersonalizationEnvelope(),
            generation: 2
        )
        var epochReads = 0
        var persistenceCalls = 0

        let result = QwertyTouchPersonalizationPersistence.persistDictionaryIfCurrent(
            snapshot: loaded,
            updatedDictionary: attemptedDictionary,
            currentEpoch: {
                defer { epochReads += 1 }
                return epochReads == 0 ? 3 : 2
            },
            currentDictionaryData: { dictionaryData },
            currentTouchData: { Data() },
            persistDictionaryData: { _ in persistenceCalls += 1 }
        )

        XCTAssertEqual(result.generation, 2)
        XCTAssertTrue(result.permitsPersistence)
        XCTAssertTrue(result.dictionary.isKnown("stored"))
        XCTAssertFalse(result.dictionary.isKnown("attempted"))
        XCTAssertEqual(persistenceCalls, 0)
        XCTAssertFalse(result.writeWasCommitted)
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

    func testPersistedOddEpochReturnsBoundedNonWritableSnapshot() {
        var staleDictionary = QwertyPersonalDictionary()
        staleDictionary.addExplicit("stale")
        var staleTouch = QwertyTouchPersonalization()
        for _ in 0..<QwertyTouchPersonalization.warmupSamples {
            staleTouch.recordAcceptedTap(
                keyCharacter: "s",
                normalizedOffset: (dx: 0.3, dy: 0)
            )
        }
        var epochReads = 0

        let snapshot = QwertyTouchPersonalizationPersistence.loadConsistentSnapshot(
            currentEpoch: {
                epochReads += 1
                return 5
            },
            currentDictionaryData: { staleDictionary.encoded() },
            currentTouchData: { staleTouch.encoded() }
        )

        XCTAssertLessThanOrEqual(epochReads, 5, "main-thread reads must use bounded polling")
        XCTAssertEqual(snapshot.generation, 5)
        XCTAssertEqual(snapshot.dictionaryStoreState, .unstableEpoch(5))
        XCTAssertEqual(snapshot.touchStoreState, .unstableEpoch(5))
        XCTAssertFalse(snapshot.permitsPersistence)
        XCTAssertFalse(snapshot.dictionary.isKnown("stale"))
        XCTAssertEqual(snapshot.touchEnvelope.loadState, .empty)
    }

    func testFinalEvenEpochPerformsFullConsistencyReadAndReturnsStablePayload() {
        var dictionary = QwertyPersonalDictionary()
        dictionary.addExplicit("stabilized")
        let dictionaryData = futureOuterPayload(
            version: 1,
            generation: 2,
            payload: dictionary.encoded()
        )
        let epochSequence = [1, 1, 1, 2]
        var observedEpochs: [Int] = []

        let snapshot = QwertyTouchPersonalizationPersistence.loadConsistentSnapshot(
            currentEpoch: {
                let epoch = epochSequence.indices.contains(observedEpochs.count)
                    ? epochSequence[observedEpochs.count]
                    : 2
                observedEpochs.append(epoch)
                return epoch
            },
            currentDictionaryData: { dictionaryData },
            currentTouchData: { Data() }
        )

        XCTAssertEqual(Array(observedEpochs.prefix(4)), epochSequence)
        XCTAssertEqual(observedEpochs.count, 5, "the final even epoch needs one bounded recheck")
        XCTAssertEqual(snapshot.generation, 2)
        XCTAssertTrue(snapshot.permitsPersistence)
        XCTAssertEqual(snapshot.dictionaryStoreState, .current)
        XCTAssertTrue(snapshot.dictionary.isKnown("stabilized"))
    }

    func testHostReloadPolicyHealsSameEpochUnstableSnapshot() {
        var dictionary = QwertyPersonalDictionary()
        dictionary.addExplicit("healed")
        let dictionaryData = futureOuterPayload(
            version: 1,
            generation: 2,
            payload: dictionary.encoded()
        )
        let unstable = QwertyTouchPersonalizationPersistence.Snapshot(
            dictionary: QwertyPersonalDictionary(),
            touchEnvelope: QwertyTouchPersonalizationEnvelope(),
            generation: 2,
            dictionaryStoreState: .unstableEpoch(2),
            touchStoreState: .unstableEpoch(2)
        )

        XCTAssertTrue(
            QwertyTouchPersonalizationPersistence.requiresHostReload(
                currentEpoch: 2,
                loadedSnapshot: unstable
            )
        )

        let healed = QwertyTouchPersonalizationPersistence.loadConsistentSnapshot(
            currentEpoch: { 2 },
            currentDictionaryData: { dictionaryData },
            currentTouchData: { Data() }
        )

        XCTAssertTrue(healed.dictionary.isKnown("healed"))
        XCTAssertTrue(healed.permitsPersistence)
        XCTAssertFalse(
            QwertyTouchPersonalizationPersistence.requiresHostReload(
                currentEpoch: 2,
                loadedSnapshot: healed
            )
        )
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

    func testLiveDictionaryWriterIsNotClearedOrRepublishedByReaderRetries() {
        let originalEpoch = UserPrefs.qwertyPersonalizationEpoch
        let originalDictionaryData = UserPrefs.qwertyPersonalDictionaryData
        let originalTouchData = UserPrefs.qwertyTouchOffsetsData
        let originalLegacyGeneration = UserPrefs.qwertyPersonalResetGeneration
        defer {
            UserPrefs.qwertyPersonalizationEpoch = originalEpoch
            UserPrefs.qwertyPersonalDictionaryData = originalDictionaryData
            UserPrefs.qwertyTouchOffsetsData = originalTouchData
            UserPrefs.qwertyPersonalResetGeneration = originalLegacyGeneration
        }

        var originalDictionary = QwertyPersonalDictionary()
        originalDictionary.addExplicit("before")
        var freshDictionary = QwertyPersonalDictionary()
        freshDictionary.addExplicit("fresh")
        UserPrefs.qwertyPersonalizationEpoch = 0
        UserPrefs.qwertyPersonalDictionaryData = originalDictionary.encoded()
        UserPrefs.qwertyTouchOffsetsData = Data()
        UserPrefs.qwertyPersonalResetGeneration = 41
        var readerSnapshot: QwertyTouchPersonalizationPersistence.Snapshot?
        var epochAfterReader: Int?
        var dictionaryAfterReader: Data?
        var touchAfterReader: Data?

        let writerResult = QwertyTouchPersonalizationPersistence.replaceDictionary(
            with: freshDictionary,
            currentEpoch: { UserPrefs.qwertyPersonalizationEpoch },
            setEpoch: { epoch in
                UserPrefs.qwertyPersonalizationEpoch = epoch
                if !epoch.isMultiple(of: 2) {
                    readerSnapshot =
                        QwertyTouchPersonalizationPersistence.loadCurrentSnapshot()
                    epochAfterReader = UserPrefs.qwertyPersonalizationEpoch
                    dictionaryAfterReader = UserPrefs.qwertyPersonalDictionaryData
                    touchAfterReader = UserPrefs.qwertyTouchOffsetsData
                }
            },
            currentDictionaryData: { UserPrefs.qwertyPersonalDictionaryData },
            currentTouchData: { UserPrefs.qwertyTouchOffsetsData },
            persistDictionaryData: { UserPrefs.qwertyPersonalDictionaryData = $0 },
            persistTouchData: { UserPrefs.qwertyTouchOffsetsData = $0 },
            incrementLegacyGeneration: {
                UserPrefs.qwertyPersonalResetGeneration += 1
            }
        )

        XCTAssertEqual(readerSnapshot?.generation, 1)
        XCTAssertEqual(readerSnapshot?.dictionaryStoreState, .unstableEpoch(1))
        XCTAssertEqual(readerSnapshot?.touchStoreState, .unstableEpoch(1))
        XCTAssertEqual(epochAfterReader, 1)
        XCTAssertEqual(dictionaryAfterReader, originalDictionary.encoded())
        XCTAssertEqual(touchAfterReader, Data())
        XCTAssertEqual(UserPrefs.qwertyPersonalResetGeneration, 42)
        XCTAssertTrue(writerResult.dictionary.isKnown("fresh"))

        let laterSnapshot = QwertyTouchPersonalizationPersistence.loadCurrentSnapshot()
        XCTAssertEqual(laterSnapshot.generation, 2)
        XCTAssertTrue(laterSnapshot.permitsPersistence)
        XCTAssertTrue(laterSnapshot.dictionary.isKnown("fresh"))
        XCTAssertFalse(laterSnapshot.dictionary.isKnown("before"))
    }

    func testProductionDictionaryReplacementRefusesPersistedOddEpochWithoutWriting() {
        let originalEpoch = UserPrefs.qwertyPersonalizationEpoch
        let originalDictionaryData = UserPrefs.qwertyPersonalDictionaryData
        let originalTouchData = UserPrefs.qwertyTouchOffsetsData
        let originalLegacyGeneration = UserPrefs.qwertyPersonalResetGeneration
        defer {
            UserPrefs.qwertyPersonalizationEpoch = originalEpoch
            UserPrefs.qwertyPersonalDictionaryData = originalDictionaryData
            UserPrefs.qwertyTouchOffsetsData = originalTouchData
            UserPrefs.qwertyPersonalResetGeneration = originalLegacyGeneration
        }

        let oddDictionaryData = Data([0x11, 0x22])
        let oddTouchData = Data([0x33, 0x44])
        UserPrefs.qwertyPersonalizationEpoch = 5
        UserPrefs.qwertyPersonalDictionaryData = oddDictionaryData
        UserPrefs.qwertyTouchOffsetsData = oddTouchData
        UserPrefs.qwertyPersonalResetGeneration = 73
        var freshDictionary = QwertyPersonalDictionary()
        freshDictionary.addExplicit("fresh")

        let result = QwertyTouchPersonalizationPersistence.replaceDictionary(
            with: freshDictionary
        )

        XCTAssertEqual(result.generation, 5)
        XCTAssertEqual(result.dictionaryStoreState, .unstableEpoch(5))
        XCTAssertEqual(result.touchStoreState, .unstableEpoch(5))
        XCTAssertFalse(result.permitsPersistence)
        XCTAssertEqual(UserPrefs.qwertyPersonalizationEpoch, 5)
        XCTAssertEqual(UserPrefs.qwertyPersonalDictionaryData, oddDictionaryData)
        XCTAssertEqual(UserPrefs.qwertyTouchOffsetsData, oddTouchData)
        XCTAssertEqual(UserPrefs.qwertyPersonalResetGeneration, 73)
    }

    func testDictionaryReplacementRefusesInitialOddEpochEvenWhenItStabilizesDuringRead() {
        var existingDictionary = QwertyPersonalDictionary()
        existingDictionary.addExplicit("existing")
        var freshDictionary = QwertyPersonalDictionary()
        freshDictionary.addExplicit("fresh")
        var epoch = 5
        var epochReads = 0
        var dictionaryData = futureOuterPayload(
            version: 1,
            generation: 6,
            payload: existingDictionary.encoded()
        )
        let originalDictionaryData = dictionaryData
        var touchData = Data()
        var setEpochs: [Int] = []
        var legacyGeneration = 0

        let result = QwertyTouchPersonalizationPersistence.replaceDictionary(
            with: freshDictionary,
            currentEpoch: {
                defer { epochReads += 1 }
                if epochReads == 0 {
                    epoch = 6
                    return 5
                }
                return epoch
            },
            setEpoch: {
                epoch = $0
                setEpochs.append($0)
            },
            currentDictionaryData: { dictionaryData },
            currentTouchData: { touchData },
            persistDictionaryData: { dictionaryData = $0 },
            persistTouchData: { touchData = $0 },
            incrementLegacyGeneration: { legacyGeneration += 1 }
        )

        XCTAssertEqual(result.generation, 5)
        XCTAssertEqual(result.dictionaryStoreState, .unstableEpoch(5))
        XCTAssertEqual(result.touchStoreState, .unstableEpoch(5))
        XCTAssertFalse(result.permitsPersistence)
        XCTAssertEqual(epoch, 6, "the other writer's completion must remain published")
        XCTAssertTrue(setEpochs.isEmpty)
        XCTAssertEqual(dictionaryData, originalDictionaryData)
        XCTAssertTrue(touchData.isEmpty)
        XCTAssertEqual(legacyGeneration, 0)
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
