import XCTest
@testable import NumPad

final class TypingQualityCountersTests: XCTestCase {
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

    func test_shortAbandonedSessionIsReportedOnce() {
        var session = TypingQualitySession()
        session.activate()
        session.recordTypingAction()
        session.recordTypingAction()

        XCTAssertTrue(session.finish())
        XCTAssertFalse(session.finish(), "one session cannot be abandoned twice")
    }

    func test_emptyOrSustainedSessionIsNotShortAbandoned() {
        var empty = TypingQualitySession()
        empty.activate()
        XCTAssertFalse(empty.finish())

        var sustained = TypingQualitySession()
        sustained.activate()
        for _ in 0...TypingQualitySession.shortSessionMaximumActions {
            sustained.recordTypingAction()
        }
        XCTAssertFalse(sustained.finish())
    }
}
