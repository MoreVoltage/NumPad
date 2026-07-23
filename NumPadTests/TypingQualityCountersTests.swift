import Darwin
import XCTest
@testable import NumPad

final class TypingQualityCountersTests: XCTestCase {
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
        XCTAssertFalse(FileManager.default.fileExists(atPath: base.fileURL.path),
                       "the injected failed replace must not fabricate persistence")

        TypingQualityCounters.increment(.pageSwitches, store: failing)
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

        XCTAssertGreaterThanOrEqual(lockAttempts, 2)
        XCTAssertEqual(TypingQualityCounters.drain(store: store), [
            Constants.typingQualityKeyTaps.rawValue: 1
        ])
    }
}
