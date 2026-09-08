import Darwin
import XCTest
@testable import NumPad

final class TypingQualityCountersTests: XCTestCase {
    func testBurstIsPersistedAsOneBatchOutsideTheInputPath() {
        let base = temporaryStore()
        var writes = 0
        let store = TypingQualityCounterStore(
            fileURL: base.fileURL,
            fileAccess: .init(write: { data, url in
                writes += 1
                try data.write(to: url, options: .atomic)
            }), flushInterval: 60)
        for _ in 0..<250 { store.increment(.keyTaps, by: 1) }
        XCTAssertEqual(writes, 0, "key taps must not perform a storage transaction")
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.fileURL.path))
        XCTAssertTrue(store.flushPending())
        XCTAssertEqual(writes, 1)
        XCTAssertEqual(TypingQualityCounters.drain(store: base)["keyTaps"], 250)
    }

    func testBlockedPersistenceDoesNotBlockAConcurrentKeyTap() {
        let base = temporaryStore()
        let writeStarted = DispatchSemaphore(value: 0)
        let releaseWrite = DispatchSemaphore(value: 0)
        let flushFinished = expectation(description: "background persistence finishes")
        let incrementFinished = expectation(description: "input remains responsive")
        let store = TypingQualityCounterStore(
            fileURL: base.fileURL,
            fileAccess: .init(write: { data, url in
                writeStarted.signal()
                XCTAssertEqual(releaseWrite.wait(timeout: .now() + 3), .success)
                try data.write(to: url, options: .atomic)
            }), flushInterval: 60)
        store.increment(.keyTaps, by: 1)
        DispatchQueue.global().async {
            _ = store.flushPending()
            flushFinished.fulfill()
        }
        XCTAssertEqual(writeStarted.wait(timeout: .now() + 1), .success)
        DispatchQueue.global().async {
            store.increment(.keyTaps, by: 1)
            incrementFinished.fulfill()
        }
        wait(for: [incrementFinished], timeout: 1)
        releaseWrite.signal()
        wait(for: [flushFinished], timeout: 2)
        // Also release the second deliberate flush, which includes the concurrent increment.
        releaseWrite.signal()
        XCTAssertEqual(store.snapshotAndSubtract()["keyTaps"], 2)
    }

    func testFailedBatchRetainsConcurrentIncrementsExactlyOnce() {
        let base = temporaryStore()
        var firstWrite = true
        var store: TypingQualityCounterStore!
        store = TypingQualityCounterStore(
            fileURL: base.fileURL,
            fileAccess: .init(write: { data, url in
                if firstWrite {
                    firstWrite = false
                    store.increment(.pageSwitches, by: 1)
                    throw TestFailure.injectedWrite
                }
                try data.write(to: url, options: .atomic)
            }), flushInterval: 60)
        store.increment(.keyTaps, by: 3)
        XCTAssertFalse(store.flushPending())
        XCTAssertTrue(store.flushPending())
        XCTAssertEqual(base.snapshotAndSubtract(), ["keyTaps": 3, "pageSwitches": 1])
        XCTAssertTrue(store.snapshotAndSubtract().isEmpty)
    }

    private enum TestFailure: Error {
        case injectedWrite
    }

    private func temporaryStore() -> TypingQualityCounterStore {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("tqc-\(UUID().uuidString)", isDirectory: true)
        return TypingQualityCounterStore(fileURL: directory.appendingPathComponent("counters.plist"))
    }

    func test_drainClearsAndReturnsIntegersOnly() {
        let store = temporaryStore()
        TypingQualityCounters.increment(.keyTaps, store: store, by: 3)
        TypingQualityCounters.increment(.suggestionsShown, store: store)
        let drained = TypingQualityCounters.drain(store: store)
        XCTAssertEqual(drained["keyTaps"], 3)
        XCTAssertEqual(drained["suggestionsShown"], 1)
        XCTAssertTrue(TypingQualityCounters.drain(store: store).isEmpty)
        XCTAssertEqual(Set(TypingQualityCounters.Event.allCases.map { $0.rawValue }).count,
                       TypingQualityCounters.Event.allCases.count)
        XCTAssertFalse(String(data: try! Data(contentsOf: store.fileURL), encoding: .utf8)?
            .contains("typed") ?? false,
                       "the persisted aggregate must never contain typed content")
    }

    func test_twoIndependentWritersDoNotLoseIncrements() {
        let first = temporaryStore()
        let second = TypingQualityCounterStore(fileURL: first.fileURL)
        let group = DispatchGroup()
        let queue = DispatchQueue(label: "TypingQualityCountersTests.concurrent",
                                  attributes: .concurrent)

        for store in [first, second] {
            group.enter()
            queue.async {
                for _ in 0..<250 {
                    TypingQualityCounters.increment(.keyTaps, store: store)
                }
                group.leave()
            }
        }

        XCTAssertEqual(group.wait(timeout: .now() + 10), .success)
        XCTAssertTrue(first.flushPending())
        XCTAssertTrue(second.flushPending())
        XCTAssertEqual(TypingQualityCounters.drain(store: first)["keyTaps"], 500)
    }

    func test_snapshotSubtractAndRestoreAreCoordinatedWithAnotherWriter() {
        let first = temporaryStore()
        let second = TypingQualityCounterStore(fileURL: first.fileURL)
        TypingQualityCounters.increment(.pageSwitches, store: first, by: 2)

        let snapshot = TypingQualityCounters.snapshotAndSubtract(store: first)
        TypingQualityCounters.increment(.pageSwitches, store: second)
        TypingQualityCounters.restore(snapshot, store: first)

        XCTAssertEqual(TypingQualityCounters.drain(store: second)["pageSwitches"], 3)
    }

    func test_userActionBoundariesHaveIndependentAggregateKeys() {
        let store = temporaryStore()
        TypingQualityCounters.increment(.backspaceTaps, store: store)
        TypingQualityCounters.increment(.backspaceRepeatSessions, store: store)
        TypingQualityCounters.increment(.correctionsApplied, store: store)
        TypingQualityCounters.increment(.correctionReverts, store: store)
        TypingQualityCounters.increment(.pageSwitches, store: store)
        TypingQualityCounters.increment(.suggestionsAccepted, store: store)

        let drained = TypingQualityCounters.drain(store: store)
        for key in ["backspaceTaps", "backspaceRepeatSessions", "correctionsApplied",
                    "correctionReverts", "pageSwitches", "suggestionsAccepted"] {
            XCTAssertEqual(drained[key], 1, "\(key) must be counted at its own boundary")
        }
    }

    func test_shortAbandonedSessionBoundariesAreOneThroughTen() {
        func isShort(_ actionCount: Int) -> Bool {
            var session = TypingQualitySession()
            session.activate()
            for _ in 0..<actionCount { session.recordTypingAction() }
            return session.finish()
        }

        XCTAssertFalse(isShort(0))
        XCTAssertTrue(isShort(1))
        XCTAssertTrue(isShort(10))
        XCTAssertFalse(isShort(11))
    }

    func test_shortAbandonedSessionIsReportedOncePerLifecycleClosure() {
        var session = TypingQualitySession()
        session.activate()
        session.recordTypingAction()

        XCTAssertTrue(session.finish())
        XCTAssertFalse(session.finish(), "one session cannot be abandoned twice")
        session.activate()
        session.recordTypingAction()
        XCTAssertTrue(session.finish(), "reactivation starts one fresh lifecycle")
    }

    func test_eventPersistenceKeysComeFromConstants() {
        let expected: Set<Constants> = [
            .typingQualityKeyTaps,
            .typingQualitySuggestionsShown,
            .typingQualitySuggestionsAccepted,
            .typingQualityCorrectionsApplied,
            .typingQualityCorrectionReverts,
            .typingQualityBackspaceTaps,
            .typingQualityBackspaceRepeatSessions,
            .typingQualityPageSwitches,
            .typingQualityShortAbandonedSessions
        ]

        XCTAssertEqual(Set(TypingQualityCounters.Event.allCases.map(\.constant)), expected)
        XCTAssertTrue(TypingQualityCounters.Event.allCases.allSatisfy {
            $0.rawValue == $0.constant.rawValue
        })
    }

    func test_hostilePersistedValuesAreIgnoredAndRestoreIsWhitelisted() throws {
        let store = temporaryStore()
        try FileManager.default.createDirectory(
            at: store.fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true)
        let hostile: [String: Any] = [
            Constants.typingQualityKeyTaps.rawValue: 4,
            Constants.typingQualityPageSwitches.rawValue: -8,
            Constants.typingQualitySuggestionsShown.rawValue: "typed-content",
            Constants.typingQualityCorrectionsApplied.rawValue: true,
            Constants.typingQualityCorrectionReverts.rawValue: 1.5,
            "typedText": "secret",
            "unknownCounter": 99
        ]
        try JSONSerialization.data(withJSONObject: hostile)
            .write(to: store.fileURL, options: .atomic)

        XCTAssertEqual(TypingQualityCounters.drain(store: store), [
            Constants.typingQualityKeyTaps.rawValue: 4
        ])

        TypingQualityCounters.restore([
            Constants.typingQualitySuggestionsAccepted.rawValue: 2,
            Constants.typingQualityCorrectionReverts.rawValue: -1,
            "typedText": 5
        ], store: store)
        XCTAssertEqual(TypingQualityCounters.drain(store: store), [
            Constants.typingQualitySuggestionsAccepted.rawValue: 2
        ])
    }

    func test_failedWriteRetainsIncrementAndRecoversExactlyOnce() {
        let base = temporaryStore()
        var failNextWrite = true
        let access = TypingQualityCounterStore.FileAccess(write: { data, url in
            if failNextWrite {
                failNextWrite = false
                throw TestFailure.injectedWrite
            }
            try data.write(to: url, options: Data.WritingOptions.atomic)
        })
        let failing = TypingQualityCounterStore(fileURL: base.fileURL, fileAccess: access)

        TypingQualityCounters.increment(.keyTaps, store: failing)
        XCTAssertFalse(failing.flushPending())
        XCTAssertFalse(FileManager.default.fileExists(atPath: base.fileURL.path),
                       "the injected failed replace must not fabricate persistence")

        TypingQualityCounters.increment(.pageSwitches, store: failing)
        XCTAssertTrue(failing.flushPending())
        let independentReader = TypingQualityCounterStore(fileURL: base.fileURL)
        XCTAssertEqual(TypingQualityCounters.drain(store: independentReader), [
            Constants.typingQualityKeyTaps.rawValue: 1,
            Constants.typingQualityPageSwitches.rawValue: 1
        ])
        XCTAssertTrue(TypingQualityCounters.drain(store: failing).isEmpty,
                      "recovered pending increments must be persisted and drained once")
    }

    func test_interruptedLockAcquisitionRetriesInsteadOfDroppingIncrement() {
        let base = temporaryStore()
        var lockAttempts = 0
        let access = TypingQualityCounterStore.FileAccess(lock: { descriptor, operation in
            lockAttempts += 1
            if lockAttempts == 1 {
                errno = EINTR
                return -1
            }
            return flock(descriptor, operation)
        })
        let store = TypingQualityCounterStore(fileURL: base.fileURL, fileAccess: access)

        TypingQualityCounters.increment(.keyTaps, store: store)

        XCTAssertTrue(store.flushPending())
        XCTAssertGreaterThanOrEqual(lockAttempts, 2)
        XCTAssertEqual(TypingQualityCounters.drain(store: store), [
            Constants.typingQualityKeyTaps.rawValue: 1
        ])
    }

    func test_uiTestResetWaitsForStaleWriterAndPreservesLockInode() throws {
        let store = temporaryStore()
        TypingQualityCounters.increment(.keyTaps, store: store)
        XCTAssertTrue(store.flushPending())
        let lockURL = store.fileURL.appendingPathExtension("lock")
        let inodeBefore = try inode(of: lockURL)
        let staleDescriptor = Darwin.open(
            lockURL.path,
            O_CREAT | O_RDWR,
            mode_t(S_IRUSR | S_IWUSR)
        )
        guard staleDescriptor >= 0 else {
            return XCTFail("Could not open the existing lock file")
        }
        XCTAssertEqual(flock(staleDescriptor, LOCK_EX), 0)
        defer {
            _ = flock(staleDescriptor, LOCK_UN)
            _ = Darwin.close(staleDescriptor)
        }

        let resetAttemptedLock = DispatchSemaphore(value: 0)
        let resetFinished = DispatchSemaphore(value: 0)
        let resettingStore = TypingQualityCounterStore(
            fileURL: store.fileURL,
            fileAccess: .init(lock: { descriptor, operation in
                resetAttemptedLock.signal()
                return flock(descriptor, operation)
            })
        )
        DispatchQueue.global(qos: .userInitiated).async {
            _ = resettingStore.resetForUITesting()
            resetFinished.signal()
        }
        XCTAssertEqual(resetAttemptedLock.wait(timeout: .now() + 1), .success)
        XCTAssertEqual(
            resetFinished.wait(timeout: .now() + 0.05),
            .timedOut,
            "Reset must wait on the existing lock inode"
        )

        let staleBag = [
            Constants.typingQualityKeyTaps.rawValue: 99
        ]
        try JSONSerialization.data(withJSONObject: staleBag)
            .write(to: store.fileURL, options: .atomic)
        XCTAssertEqual(flock(staleDescriptor, LOCK_UN), 0)
        XCTAssertEqual(resetFinished.wait(timeout: .now() + 2), .success)

        XCTAssertEqual(try inode(of: lockURL), inodeBefore)
        XCTAssertTrue(FileManager.default.fileExists(atPath: lockURL.path))
        XCTAssertTrue(TypingQualityCounters.drain(store: store).isEmpty)
    }

    private func inode(of url: URL) throws -> UInt64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes[.systemFileNumber] as? NSNumber)?.uint64Value ?? 0
    }
}
