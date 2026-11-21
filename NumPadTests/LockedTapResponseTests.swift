//
//  LockedTapResponseTests.swift
//  NumPadTests
//
//  App Review 4.4.1: a keyboard extension may not launch other apps (Settings excepted). A locked
//  tap must therefore never try to open NumPad. It counts the tap and shows a short in-keyboard
//  hint instead.
//
//  The three locked entry points in `KeyboardViewController` (key tap, pack picker, conversion
//  category) are one-line delegations to `LockedTapResponse.handleKeyTap` /
//  `handleLockedOverlaySelection`, and the hint's lifetime is owned by `LockedTapHintCoordinator`.
//  Those are exercised here against spies and a virtual clock; the controller itself lives in the
//  extension target and cannot be hosted by this app test bundle.
//

import XCTest
@testable import NumPad

// MARK: - Spies

/// A responder that records every app-launch style call that could reach it: the legacy
/// `openURL:` selector and the modern `open(_:options:completionHandler:)` shape.
private final class LaunchSpyResponder: UIResponder {
    private(set) var legacyOpenCalls = 0
    private(set) var modernOpenCalls = 0
    var nextSpy: UIResponder?

    override var next: UIResponder? { nextSpy }

    @objc func openURL(_ url: URL) -> Bool {
        legacyOpenCalls += 1
        return true
    }

    @objc(openURL:options:completionHandler:)
    func open(_ url: URL, options: [String: Any], completionHandler: ((Bool) -> Void)?) {
        modernOpenCalls += 1
        completionHandler?(true)
    }
}

/// Hint presenter that sits at the head of a spy responder chain, as the keyboard view controller
/// does in production. Records the order of what the entry points ask it to do.
private final class HintPresenterSpy: UIResponder, LockedTapHintPresenting {
    enum Event: Equatable { case dismissOverlays, showHint(String) }
    private(set) var events: [Event] = []
    let chain: LaunchSpyResponder

    init(chain: LaunchSpyResponder) {
        self.chain = chain
        super.init()
    }

    override var next: UIResponder? { chain }

    var shownHints: [String] {
        events.compactMap { if case .showHint(let message) = $0 { return message } else { return nil } }
    }

    func showLockedTapHint(_ message: String) { events.append(.showHint(message)) }
    func dismissOverlaysForLockedTap() { events.append(.dismissOverlays) }
}

/// Virtual clock. Nothing runs until the test advances time.
private final class FakeScheduler: LockedTapHintScheduling {
    private final class Entry: LockedTapHintCancellable {
        let fireAt: TimeInterval
        let action: () -> Void
        var cancelled = false
        init(fireAt: TimeInterval, action: @escaping () -> Void) {
            self.fireAt = fireAt
            self.action = action
        }
        func cancel() { cancelled = true }
    }

    private(set) var now: TimeInterval = 0
    private var entries: [Entry] = []

    func schedule(after delay: TimeInterval, _ action: @escaping () -> Void) -> LockedTapHintCancellable {
        let entry = Entry(fireAt: now + delay, action: action)
        entries.append(entry)
        return entry
    }

    func advance(by interval: TimeInterval) {
        let target = now + interval
        while let next = entries.filter({ !$0.cancelled && $0.fireAt <= target }).min(by: { $0.fireAt < $1.fireAt }) {
            entries.removeAll { $0 === next }
            now = next.fireAt
            next.action()
        }
        now = target
    }
}

/// Stands in for the controller's view work. Fade-out completions are held so a test can decide
/// exactly when the 0.2 s animation "finishes", including after a newer tap.
private final class FakeHintSurface: LockedTapHintSurface {
    weak var coordinator: LockedTapHintCoordinator?
    private(set) var shown: [String] = []
    private(set) var fadeOutsStarted = 0
    private(set) var hides = 0
    private(set) var chipsAllowedAtHide: [Bool] = []
    var viewHidden = true
    var pendingFadeCompletions: [() -> Void] = []

    func lockedTapHintShow(_ message: String) {
        shown.append(message)
        viewHidden = false
    }

    func lockedTapHintFadeOut(completion: @escaping () -> Void) {
        fadeOutsStarted += 1
        pendingFadeCompletions.append(completion)
    }

    func lockedTapHintDidHide() {
        hides += 1
        viewHidden = true
        chipsAllowedAtHide.append(coordinator?.allowsChips ?? false)
    }

    func finishFade(at index: Int) { pendingFadeCompletions[index]() }
}

// MARK: - Tests

final class LockedTapResponseTests: XCTestCase {
    private var savedLockedTaps = 0
    private var savedStoreOpens = 0

    override func setUp() {
        super.setUp()
        savedLockedTaps = LockFunnelCounters.lockedKeyTaps
        savedStoreOpens = LockFunnelCounters.storeDeeplinkOpens
        LockFunnelCounters.lockedKeyTaps = 0
        LockFunnelCounters.storeDeeplinkOpens = 0
    }

    override func tearDown() {
        LockFunnelCounters.lockedKeyTaps = savedLockedTaps
        LockFunnelCounters.storeDeeplinkOpens = savedStoreOpens
        super.tearDown()
    }

    private func makePresenter() -> (HintPresenterSpy, [LaunchSpyResponder]) {
        let tail = LaunchSpyResponder()
        let head = LaunchSpyResponder()
        head.nextSpy = tail
        return (HintPresenterSpy(chain: head), [head, tail])
    }

    private func assertNoLaunch(_ spies: [LaunchSpyResponder], _ context: String,
                                file: StaticString = #filePath, line: UInt = #line) {
        for spy in spies {
            XCTAssertEqual(spy.legacyOpenCalls, 0, "openURL: reached a responder (\(context))", file: file, line: line)
            XCTAssertEqual(spy.modernOpenCalls, 0, "open(_:options:) reached a responder (\(context))", file: file, line: line)
        }
    }

    private func makeCoordinator() -> (LockedTapHintCoordinator, FakeScheduler, FakeHintSurface) {
        let scheduler = FakeScheduler()
        let surface = FakeHintSurface()
        let coordinator = LockedTapHintCoordinator(scheduler: scheduler)
        coordinator.surface = surface
        surface.coordinator = coordinator
        return (coordinator, scheduler, surface)
    }

    private var duration: TimeInterval { LockedTapResponse.hintDisplayDuration }

    // MARK: Entry points (KeyboardViewController.tapped / packPicker / conversion)

    func testLockedKeyTapShowsHintNoLaunchAndConsumesTap() {
        let (presenter, spies) = makePresenter()
        let consumed = LockedTapResponse.handleKeyTap(isLocked: true, presenter: presenter)
        XCTAssertTrue(consumed, "a locked key must stop tapped(_:) before any other key action")
        XCTAssertEqual(presenter.events, [.showHint(LockedTapResponse.hintMessage)])
        XCTAssertEqual(LockFunnelCounters.lockedKeyTaps, 1)
        XCTAssertEqual(LockFunnelCounters.storeDeeplinkOpens, 0)
        assertNoLaunch(spies, "key lock")
    }

    func testUnlockedKeyTapFallsThroughUntouched() {
        let (presenter, spies) = makePresenter()
        let consumed = LockedTapResponse.handleKeyTap(isLocked: false, presenter: presenter)
        XCTAssertFalse(consumed)
        XCTAssertTrue(presenter.events.isEmpty)
        XCTAssertEqual(LockFunnelCounters.lockedKeyTaps, 0)
        assertNoLaunch(spies, "unlocked key")
    }

    func testLockedOverlaySelectionDismissesOverlayBeforeHintAndNeverLaunches() {
        for source in [LockedTapSource.packPicker, .conversionLock] {
            let (presenter, spies) = makePresenter()
            LockedTapResponse.handleLockedOverlaySelection(source: source, presenter: presenter)
            XCTAssertEqual(presenter.events, [.dismissOverlays, .showHint(LockedTapResponse.hintMessage)], "\(source)")
            assertNoLaunch(spies, "\(source)")
        }
        XCTAssertEqual(LockFunnelCounters.lockedKeyTaps, 2)
        XCTAssertEqual(LockFunnelCounters.storeDeeplinkOpens, 0)
    }

    func testHintMessageNamesTheApp() {
        XCTAssertTrue(LockedTapResponse.hintMessage.contains("NumPad"))
    }

    /// "Non-blocking" means brief: the hint must clear well before it gets in the way of typing.
    func testHintIsTransient() {
        XCTAssertGreaterThan(duration, 0)
        XCTAssertLessThanOrEqual(duration, 3)
    }

    // MARK: Presentation timing (virtual clock)

    func testHintExpiresAfterDurationAndRestoresChips() {
        let (coordinator, scheduler, surface) = makeCoordinator()
        coordinator.present("hint")
        XCTAssertFalse(coordinator.allowsChips, "no chip may appear under a visible hint")

        scheduler.advance(by: duration - 0.25)
        XCTAssertEqual(surface.fadeOutsStarted, 0)
        scheduler.advance(by: 0.25)
        XCTAssertEqual(surface.fadeOutsStarted, 1)
        XCTAssertFalse(coordinator.allowsChips, "still gated while fading out")

        surface.finishFade(at: 0)
        XCTAssertEqual(surface.hides, 1)
        XCTAssertTrue(surface.viewHidden)
        XCTAssertEqual(surface.chipsAllowedAtHide, [true],
                       "chips must be un-gated before the restore runs, so an unchanged expression gets its math chip back")
        XCTAssertTrue(coordinator.allowsChips)
    }

    func testTapJustBeforeDeadlineRestartsTheTimer() {
        let (coordinator, scheduler, surface) = makeCoordinator()
        coordinator.present("first")
        scheduler.advance(by: duration - 0.25) // just before the first deadline
        coordinator.present("second")

        scheduler.advance(by: 0.25) // first deadline: must not fire
        XCTAssertEqual(surface.fadeOutsStarted, 0)
        XCTAssertFalse(coordinator.allowsChips)

        scheduler.advance(by: duration - 0.5)
        XCTAssertEqual(surface.fadeOutsStarted, 0)
        scheduler.advance(by: 0.25) // second deadline
        XCTAssertEqual(surface.fadeOutsStarted, 1)
        surface.finishFade(at: 0)
        XCTAssertEqual(surface.hides, 1)
        XCTAssertEqual(surface.shown, ["first", "second"])
    }

    func testTapDuringFadeOutKeepsTheNewHint() {
        let (coordinator, scheduler, surface) = makeCoordinator()
        coordinator.present("first")
        scheduler.advance(by: duration)
        XCTAssertEqual(surface.fadeOutsStarted, 1, "first hint is fading")

        coordinator.present("second") // lands inside the 0.2 s fade
        surface.finishFade(at: 0)      // the stale completion arrives afterwards
        XCTAssertEqual(surface.hides, 0, "a superseded fade-out must not hide the new hint")
        XCTAssertFalse(surface.viewHidden)
        XCTAssertFalse(coordinator.allowsChips, "chips stay gated for the new hint")

        scheduler.advance(by: duration)
        XCTAssertEqual(surface.fadeOutsStarted, 2)
        surface.finishFade(at: 1)
        XCTAssertEqual(surface.hides, 1)
        XCTAssertTrue(coordinator.allowsChips)
    }

    func testChipsAllowedWhenNoHintWasShown() {
        let (coordinator, _, _) = makeCoordinator()
        XCTAssertTrue(coordinator.allowsChips)
    }

    // MARK: Layout

    func testHintAllowsTwoLinesWithABoundedHeight() {
        XCTAssertEqual(LockedTapHintLayout.maxLines, 2)
        let cap = LockedTapHintLayout.maxHeight(lineHeight: 16)
        XCTAssertEqual(cap, 2 * 16 + 2 * LockedTapHintLayout.verticalPadding)
        XCTAssertGreaterThanOrEqual(cap, LockedTapHintLayout.minHeight)
        XCTAssertGreaterThan(LockedTapHintLayout.maxHeight(lineHeight: 24), cap, "cap grows with text size")
    }

    // MARK: Source audit

    /// The keyboard extension must not build store deep links or bump the store-open counter.
    /// Scans every Swift file in the extension's own folder plus the shared locked-tap file, and
    /// does not depend on any particular launch helper still existing.
    func testKeyboardSourcesHaveNoStoreLaunchPath() throws {
        let sources = try keyboardSources()
        XCTAssertFalse(sources.isEmpty, "no keyboard sources found")
        for (path, text) in sources {
            XCTAssertFalse(text.contains("store-preview"), "\(path) builds a store deep link")
            XCTAssertFalse(text.contains("incrementStoreDeeplinkOpens"), "\(path) counts store opens")
        }
    }

    private func keyboardSources() throws -> [(String, String)] {
        let repoRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let keyboardDir = repoRoot.appendingPathComponent("Keyboard")
        var files: [URL] = [repoRoot.appendingPathComponent("NumPad/Libraries/LockedTapResponse.swift")]
        let enumerator = FileManager.default.enumerator(at: keyboardDir, includingPropertiesForKeys: nil)
        while let url = enumerator?.nextObject() as? URL {
            if url.pathExtension == "swift" { files.append(url) }
        }
        return try files.map { ($0.lastPathComponent, try String(contentsOf: $0, encoding: .utf8)) }
    }
}
