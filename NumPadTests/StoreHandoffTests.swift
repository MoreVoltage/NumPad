//
//  StoreHandoffTests.swift
//  NumPadTests
//
//  Locked tap in the keyboard -> the user opens NumPad soon after -> the app shows the existing
//  Store once. The keyboard never launches the app (App Review 4.4.1); it only leaves a small
//  record in the shared App Group defaults. Everything here runs against an isolated defaults
//  suite and an injected clock.
//

import XCTest
@testable import NumPad

private final class TestClock {
    var now = Date(timeIntervalSince1970: 1_800_000_000)
    func advance(_ seconds: TimeInterval) { now = now.addingTimeInterval(seconds) }
}

private final class PresenterStub: LockedTapHintPresenting {
    func showLockedTapHint(_ message: String) {}
    func dismissOverlaysForLockedTap() {}
}

final class StoreHandoffTests: XCTestCase {
    private var suiteName = ""
    private var defaults: UserDefaults!
    private var clock: TestClock!
    private var store: StoreHandoffStore!
    private var savedRecorder: StoreHandoffStore!
    private var savedLockedTaps = 0

    private let ready = StoreHandoffContext(isAppReady: true, isStoreVisible: false)
    private let allLocked: (StoreHandoffRecord) -> Bool = { _ in true }

    override func setUp() {
        super.setUp()
        suiteName = "StoreHandoffTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        clock = TestClock()
        let clock = self.clock!
        store = StoreHandoffStore(defaults: defaults, now: { clock.now })
        savedRecorder = LockedTapResponse.handoffStore
        LockedTapResponse.handoffStore = store
        savedLockedTaps = LockFunnelCounters.lockedKeyTaps
    }

    override func tearDown() {
        LockedTapResponse.handoffStore = savedRecorder
        LockFunnelCounters.lockedKeyTaps = savedLockedTaps
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    // MARK: Window

    func testWindowIsTenMinutes() {
        XCTAssertEqual(StoreHandoff.window, 10 * 60)
    }

    // MARK: Record write

    func testRecordWritesTimestampSourceAndPack() {
        store.record(source: .keyLock, pack: .finance)
        XCTAssertEqual(store.load(), StoreHandoffRecord(timestamp: clock.now, source: .keyLock, pack: .finance))
    }

    func testRecordWithoutPack() {
        store.record(source: .conversionLock, pack: nil)
        XCTAssertEqual(store.load(), StoreHandoffRecord(timestamp: clock.now, source: .conversionLock, pack: nil))
    }

    func testLatestTapWins() {
        store.record(source: .keyLock, pack: .finance)
        clock.advance(30)
        store.record(source: .packPicker, pack: .programmer)
        XCTAssertEqual(store.load(), StoreHandoffRecord(timestamp: clock.now, source: .packPicker, pack: .programmer))
    }

    func testMalformedRecordLoadsAsNil() {
        defaults.set("garbage", forKey: StoreHandoffStore.key)
        XCTAssertNil(store.load())
        defaults.set(["t": 1.0, "s": "nope"], forKey: StoreHandoffStore.key)
        XCTAssertNil(store.load())
    }

    func testKeyTapEntryPointWritesRecord() {
        XCTAssertTrue(LockedTapResponse.handleKeyTap(isLocked: true, pack: .symbols, presenter: PresenterStub()))
        XCTAssertEqual(store.load()?.source, .keyLock)
        XCTAssertEqual(store.load()?.pack, .symbols)
    }

    func testUnlockedKeyTapWritesNothing() {
        XCTAssertFalse(LockedTapResponse.handleKeyTap(isLocked: false, pack: .symbols, presenter: PresenterStub()))
        XCTAssertNil(store.load())
    }

    func testOverlayEntryPointsWriteRecord() {
        LockedTapResponse.handleLockedOverlaySelection(source: .packPicker, pack: .units, presenter: PresenterStub())
        XCTAssertEqual(store.load(), StoreHandoffRecord(timestamp: clock.now, source: .packPicker, pack: .units))
        LockedTapResponse.handleLockedOverlaySelection(source: .conversionLock, presenter: PresenterStub())
        XCTAssertEqual(store.load(), StoreHandoffRecord(timestamp: clock.now, source: .conversionLock, pack: nil))
    }

    // MARK: Source naming (reuses the Store's existing lock sources)

    func testStoreSourcesMatchExistingLockSources() {
        XCTAssertEqual(LockedTapSource.keyLock.storeSource, "key_lock")
        XCTAssertEqual(LockedTapSource.packPicker.storeSource, "pack_picker")
        XCTAssertEqual(LockedTapSource.conversionLock.storeSource, "conversion_lock")
        for source in LockedTapSource.allCases {
            XCTAssertEqual(LockedTapSource(storeSource: source.storeSource), source)
        }
    }

    // MARK: Routing decision (pure)

    private func record(age: TimeInterval, source: LockedTapSource = .keyLock, pack: KeyboardType? = .finance) -> StoreHandoffRecord {
        StoreHandoffRecord(timestamp: clock.now.addingTimeInterval(-age), source: source, pack: pack)
    }

    func testNoRecordDoesNothing() {
        XCTAssertEqual(StoreHandoff.decide(record: nil, now: clock.now, context: ready, isStillLocked: allLocked), .none)
    }

    func testFreshLockedRecordPresentsWithItsSource() {
        XCTAssertEqual(StoreHandoff.decide(record: record(age: 5), now: clock.now, context: ready, isStillLocked: allLocked),
                       .present(source: "key_lock"))
        XCTAssertEqual(StoreHandoff.decide(record: record(age: 5, source: .conversionLock, pack: nil), now: clock.now,
                                           context: ready, isStillLocked: allLocked),
                       .present(source: "conversion_lock"))
    }

    func testRecordAtExactWindowEdgeStillPresents() {
        XCTAssertEqual(StoreHandoff.decide(record: record(age: StoreHandoff.window), now: clock.now, context: ready,
                                           isStillLocked: allLocked), .present(source: "key_lock"))
    }

    func testExpiredRecordIsDiscarded() {
        XCTAssertEqual(StoreHandoff.decide(record: record(age: StoreHandoff.window + 1), now: clock.now, context: ready,
                                           isStillLocked: allLocked), .discard)
    }

    func testFutureTimestampIsDiscarded() {
        XCTAssertEqual(StoreHandoff.decide(record: record(age: -60), now: clock.now, context: ready,
                                           isStillLocked: allLocked), .discard)
    }

    func testEntitledUserIsSkipped() {
        XCTAssertEqual(StoreHandoff.decide(record: record(age: 5), now: clock.now, context: ready,
                                           isStillLocked: { _ in false }), .discard)
    }

    func testStoreAlreadyVisibleConsumesWithoutPresenting() {
        let context = StoreHandoffContext(isAppReady: true, isStoreVisible: true)
        XCTAssertEqual(StoreHandoff.decide(record: record(age: 5), now: clock.now, context: context,
                                           isStillLocked: allLocked), .discard)
    }

    func testAppNotReadyWaits() {
        let context = StoreHandoffContext(isAppReady: false, isStoreVisible: false)
        XCTAssertEqual(StoreHandoff.decide(record: record(age: 5), now: clock.now, context: context,
                                           isStillLocked: allLocked), .wait)
    }

    // MARK: Consumption

    func testConsumePresentsExactlyOnce() {
        store.record(source: .packPicker, pack: .units)
        clock.advance(60)
        XCTAssertEqual(StoreHandoff.consume(store: store, context: ready, isStillLocked: allLocked), "pack_picker")
        XCTAssertNil(store.load(), "record cleared after presenting")
        XCTAssertNil(StoreHandoff.consume(store: store, context: ready, isStillLocked: allLocked), "second foreground: nothing")
    }

    func testConsumeClearsStaleRecord() {
        store.record(source: .keyLock, pack: .finance)
        clock.advance(StoreHandoff.window + 1)
        XCTAssertNil(StoreHandoff.consume(store: store, context: ready, isStillLocked: allLocked))
        XCTAssertNil(store.load())
    }

    func testConsumeClearsRecordForEntitledUser() {
        store.record(source: .keyLock, pack: .finance)
        XCTAssertNil(StoreHandoff.consume(store: store, context: ready, isStillLocked: { _ in false }))
        XCTAssertNil(store.load())
    }

    func testConsumeKeepsRecordWhileAppNotReadyThenPresents() {
        store.record(source: .keyLock, pack: .finance)
        let busy = StoreHandoffContext(isAppReady: false, isStoreVisible: false)
        XCTAssertNil(StoreHandoff.consume(store: store, context: busy, isStillLocked: allLocked))
        XCTAssertNotNil(store.load(), "kept for the next chance inside the window")
        XCTAssertEqual(StoreHandoff.consume(store: store, context: ready, isStillLocked: allLocked), "key_lock")
        XCTAssertNil(store.load())
    }

    func testConsumeClearsMalformedRecord() {
        defaults.set("garbage", forKey: StoreHandoffStore.key)
        XCTAssertNil(StoreHandoff.consume(store: store, context: ready, isStillLocked: allLocked))
        XCTAssertNil(defaults.object(forKey: StoreHandoffStore.key))
    }

    // MARK: Entitlement mapping (pure)

    private func stillLocked(_ record: StoreHandoffRecord, paywall: Bool = true, pro: Bool = false,
                             locked: Set<KeyboardType> = []) -> Bool {
        StoreHandoff.isStillLocked(record, paywallEnabled: paywall, isProEntitled: pro,
                                   isPackLocked: { locked.contains($0) })
    }

    func testPaywallOffIsNeverLocked() {
        XCTAssertFalse(stillLocked(record(age: 0), paywall: false, locked: [.finance]))
    }

    func testRecordedPackUsesPackLock() {
        XCTAssertTrue(stillLocked(record(age: 0, pack: .finance), locked: [.finance]))
        XCTAssertFalse(stillLocked(record(age: 0, pack: .finance), locked: [.symbols]), "pack bought since the tap")
    }

    func testConversionLockWithoutPackChecksBothConverterPacks() {
        let conv = record(age: 0, source: .conversionLock, pack: nil)
        XCTAssertTrue(stillLocked(conv, locked: [.cooking]))
        XCTAssertTrue(stillLocked(conv, locked: [.units]))
        XCTAssertFalse(stillLocked(conv, locked: []))
    }

    func testUnknownPackFallsBackToPro() {
        let keyNoPack = record(age: 0, source: .keyLock, pack: nil)
        XCTAssertTrue(stillLocked(keyNoPack, pro: false))
        XCTAssertFalse(stillLocked(keyNoPack, pro: true))
    }
}
