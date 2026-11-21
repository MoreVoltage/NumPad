//
//  LockedTapResponseTests.swift
//  NumPadTests
//
//  App Review 4.4.1: a keyboard extension may not launch other apps (Settings excepted). A locked
//  tap must therefore never try to open NumPad. It counts the tap and shows a short in-keyboard
//  hint instead.
//

import XCTest
@testable import NumPad

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
/// does in production.
private final class HintPresenterSpy: UIResponder, LockedTapHintPresenting {
    private(set) var shownHints: [String] = []
    let chain: LaunchSpyResponder

    init(chain: LaunchSpyResponder) {
        self.chain = chain
        super.init()
    }

    override var next: UIResponder? { chain }

    func showLockedTapHint(_ message: String) {
        shownHints.append(message)
    }
}

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

    private func makePresenter() -> (HintPresenterSpy, LaunchSpyResponder, LaunchSpyResponder) {
        let tail = LaunchSpyResponder()
        let head = LaunchSpyResponder()
        head.nextSpy = tail
        return (HintPresenterSpy(chain: head), head, tail)
    }

    func testLockedTapNeverReachesAnyLaunchResponder() {
        for source in LockedTapSource.allCases {
            let (presenter, head, tail) = makePresenter()
            LockedTapResponse.handle(source: source, presenter: presenter)
            for spy in [head, tail] {
                XCTAssertEqual(spy.legacyOpenCalls, 0, "openURL: reached a responder for \(source)")
                XCTAssertEqual(spy.modernOpenCalls, 0, "open(_:options:) reached a responder for \(source)")
            }
        }
    }

    func testLockedTapShowsOneNonEmptyHintNamingTheApp() {
        for source in LockedTapSource.allCases {
            let (presenter, _, _) = makePresenter()
            LockedTapResponse.handle(source: source, presenter: presenter)
            XCTAssertEqual(presenter.shownHints.count, 1, "\(source)")
            XCTAssertEqual(presenter.shownHints.first, LockedTapResponse.hintMessage)
        }
        XCTAssertTrue(LockedTapResponse.hintMessage.contains("NumPad"))
    }

    func testLockedTapIncrementsLockedTapCounter() {
        let (presenter, _, _) = makePresenter()
        LockedTapResponse.handle(source: .keyLock, presenter: presenter)
        LockedTapResponse.handle(source: .packPicker, presenter: presenter)
        LockedTapResponse.handle(source: .conversionLock, presenter: presenter)
        XCTAssertEqual(LockFunnelCounters.lockedKeyTaps, 3)
    }

    func testLockedTapNeverIncrementsStoreDeeplinkOpens() {
        let (presenter, _, _) = makePresenter()
        for source in LockedTapSource.allCases {
            LockedTapResponse.handle(source: source, presenter: presenter)
        }
        XCTAssertEqual(LockFunnelCounters.storeDeeplinkOpens, 0)
    }

    /// "Non-blocking" means brief: the hint must clear well before it gets in the way of typing.
    func testHintIsTransient() {
        XCTAssertGreaterThan(LockedTapResponse.hintDisplayDuration, 0)
        XCTAssertLessThanOrEqual(LockedTapResponse.hintDisplayDuration, 3)
    }

    /// Source guard: the keyboard extension must not build store deep links or bump the
    /// store-open counter anywhere. The only remaining `openContainerApp` caller is the What's
    /// New chip (out of scope here; MOR-400 removes that chip on another branch).
    func testKeyboardSourceHasNoStoreLaunchPath() throws {
        let source = try keyboardControllerSource()
        XCTAssertFalse(source.contains("store-preview"), "keyboard still builds a store deep link")
        XCTAssertFalse(source.contains("incrementStoreDeeplinkOpens"), "keyboard still counts store opens")
        XCTAssertEqual(source.components(separatedBy: "openContainerApp(").count - 1, 2,
                       "expected only the definition plus the What's New chip call")
    }

    private func keyboardControllerSource() throws -> String {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let file = repoRoot.appendingPathComponent("Keyboard/KeyboardViewController.swift")
        return try String(contentsOf: file, encoding: .utf8)
    }
}
