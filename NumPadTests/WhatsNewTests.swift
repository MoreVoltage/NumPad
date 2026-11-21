import XCTest
import UserNotifications
@testable import NumPad

final class WhatsNewGateTests: XCTestCase {
    func testShouldPresentWhenLastSeenIsNil() {
        XCTAssertTrue(WhatsNew.shouldPresent(lastSeen: nil, current: "2.0.3"))
    }

    func testShouldPresentWhenLastSeenIsOlderThanCut() {
        XCTAssertTrue(WhatsNew.shouldPresent(lastSeen: "2.0", current: "2.0.3"))
        XCTAssertTrue(WhatsNew.shouldPresent(lastSeen: "2.0.2", current: "2.0.3"))
    }

    func testShouldNotPresentAfterMarkedSeen() {
        XCTAssertFalse(WhatsNew.shouldPresent(lastSeen: "2.0.3", current: "2.0.3"))
    }

    func testShouldNotPresentWhenCurrentIsOlderThanCut() {
        XCTAssertFalse(WhatsNew.shouldPresent(lastSeen: nil, current: "2.0.2"))
        XCTAssertFalse(WhatsNew.shouldPresent(lastSeen: nil, current: "2.0"))
    }

    func testShouldNotPresentWhenLastSeenIsNewerCut() {
        XCTAssertFalse(WhatsNew.shouldPresent(lastSeen: "2.0.4", current: "2.0.3"))
    }

    func testChipVisibilityFollowsTheSameFlag() {
        let cases: [(String?, String)] = [
            (nil, "2.0.3"),
            ("2.0.2", "2.0.3"),
            ("2.0.3", "2.0.3"),
            (nil, "2.0.2"),
            ("2.0", "2.0.3")
        ]
        for (lastSeen, current) in cases {
            XCTAssertEqual(
                WhatsNew.isChipVisible(lastSeen: lastSeen, current: current),
                WhatsNew.shouldPresent(lastSeen: lastSeen, current: current),
                "chip visibility must match shouldPresent(lastSeen: \(String(describing: lastSeen)), current: \(current))"
            )
        }
    }

    func testCanPresentWaitsForOnboardingAndPaywall() {
        XCTAssertTrue(WhatsNew.canPresent(hasModal: false, navShowingOtherScreen: false))
        XCTAssertFalse(WhatsNew.canPresent(hasModal: true, navShowingOtherScreen: false))
        XCTAssertFalse(WhatsNew.canPresent(hasModal: false, navShowingOtherScreen: true))
        XCTAssertFalse(WhatsNew.canPresent(hasModal: true, navShowingOtherScreen: true))
    }
}

final class AppDeepLinkTests: XCTestCase {
    private func url(_ string: String) -> URL {
        URL(string: string)!
    }

    func testWhatsNewIsParsedInRelease() {
        XCTAssertEqual(AppDeepLink.parse(url("numpad://whats-new")), .whatsNew)
        XCTAssertTrue(WhatsNew.matchesDeepLink(url("numpad://whats-new")))
    }

    func testStorePreviewStillParsed() {
        XCTAssertEqual(
            AppDeepLink.parse(url("numpad://store-preview?source=key_lock")),
            .storePreview(source: "key_lock")
        )
        XCTAssertEqual(AppDeepLink.parse(url("numpad://store-preview")), .storePreview(source: nil))
    }

    func testDebugHostIsNotAnAppDeepLink() {
        XCTAssertNil(AppDeepLink.parse(url("numpad://debug/height")))
        XCTAssertFalse(WhatsNew.matchesDeepLink(url("numpad://debug/height")))
    }

    func testUnknownHostReturnsNil() {
        XCTAssertNil(AppDeepLink.parse(url("numpad://unknown")))
        XCTAssertFalse(WhatsNew.matchesDeepLink(url("numpad://store-preview")))
    }

    func testWrongSchemeReturnsNil() {
        XCTAssertNil(AppDeepLink.parse(url("https://whats-new")))
        XCTAssertFalse(WhatsNew.matchesDeepLink(url("https://example.com/whats-new")))
    }
}

private final class RecordingNotificationCenter: WhatsNewNotificationScheduling {
    private(set) var added: [UNNotificationRequest] = []

    func add(_ request: UNNotificationRequest, withCompletionHandler completionHandler: ((Error?) -> Void)?) {
        added.append(request)
        completionHandler?(nil)
    }
}

final class WhatsNewNotificationTests: XCTestCase {
    func testGrantAddsExactlyOneRequest() {
        let center = RecordingNotificationCenter()
        let scheduled = WhatsNewNotification.addRequestIfNeeded(granted: true, alreadyScheduled: false, center: center)
        XCTAssertTrue(scheduled)
        XCTAssertEqual(center.added.count, 1)
        XCTAssertEqual(center.added[0].identifier, WhatsNewNotification.requestID)
        XCTAssertEqual(center.added[0].identifier, "numpad.whatsnew.once")
    }

    func testDenyAddsZeroRequests() {
        let center = RecordingNotificationCenter()
        let scheduled = WhatsNewNotification.addRequestIfNeeded(granted: false, alreadyScheduled: false, center: center)
        XCTAssertFalse(scheduled)
        XCTAssertTrue(center.added.isEmpty)
        XCTAssertNil(WhatsNewNotification.makeRequest(granted: false, alreadyScheduled: false))
    }

    func testAlreadyScheduledDoesNotAddAnother() {
        let center = RecordingNotificationCenter()
        XCTAssertTrue(WhatsNewNotification.addRequestIfNeeded(granted: true, alreadyScheduled: false, center: center))
        XCTAssertTrue(WhatsNewNotification.addRequestIfNeeded(granted: true, alreadyScheduled: true, center: center))
        XCTAssertEqual(center.added.count, 1)
    }

    func testDoesNotTouchEarlyBirdIdentifiers() {
        let center = RecordingNotificationCenter()
        _ = WhatsNewNotification.addRequestIfNeeded(granted: true, alreadyScheduled: false, center: center)
        let ids = center.added.map(\.identifier)
        XCTAssertFalse(ids.contains("numpad.earlybird.reminder1"))
        XCTAssertFalse(ids.contains("numpad.earlybird.reminder2"))
        XCTAssertEqual(WhatsNewNotification.requestID, "numpad.whatsnew.once")
        XCTAssertNotEqual(WhatsNewNotification.requestID, "numpad.earlybird.reminder1")
        XCTAssertNotEqual(WhatsNewNotification.requestID, "numpad.earlybird.reminder2")
    }

    func testTriggerIsOneShotTwentyFourHours() {
        let request = WhatsNewNotification.makeRequest(granted: true, alreadyScheduled: false)
        let trigger = request?.trigger as? UNTimeIntervalNotificationTrigger
        XCTAssertEqual(trigger?.repeats, false)
        XCTAssertEqual(trigger?.timeInterval, 24 * 3600)
        XCTAssertEqual(WhatsNewNotification.authorizationOptions, [.alert, .sound, .provisional])
    }
}

// MARK: - MOR-400: the keyboard must not carry a What's New promotion

/// MOR-400: the keyboard's What's New chip could not be opened (the `openURL:` responder-chain
/// trick it relied on), could not be dismissed (it only hid once the *container* marked the recap
/// seen, which the keyboard may never observe), and sat over the top-left keys (+ and −) of the
/// grid on iPad. The fix removes the promotion from the keyboard entirely; the in-app sheet and the
/// one-shot notification still announce updates.
///
/// The Keyboard extension is not linked into this app-hosted test bundle, so
/// `KeyboardViewController` cannot be instantiated here. This guard instead pins the contract at
/// the source level: no keyboard view, no keyboard code path, and no Keyboard-target build entry
/// may (re)introduce a What's New promotion. The live-keyboard half (+ and − unobstructed) is
/// `ScreenshotCaptureTests.testMOR400_mathRowPlusMinusUnobstructed`.
final class KeyboardWhatsNewPromotionRemovedTests: XCTestCase {
    private let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    private func keyboardSwiftSources() throws -> [URL] {
        let keyboardDir = repoRoot.appendingPathComponent("Keyboard")
        guard let enumerator = FileManager.default.enumerator(at: keyboardDir, includingPropertiesForKeys: nil) else {
            XCTFail("Keyboard sources not readable at \(keyboardDir.path)")
            return []
        }
        let sources = enumerator.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
        XCTAssertFalse(sources.isEmpty, "found no Keyboard/*.swift sources — repo root resolved wrong?")
        return sources
    }

    func testKeyboardShipsNoWhatsNewChipView() {
        let chipPath = repoRoot.appendingPathComponent("Keyboard/Views/WhatsNewChipView.swift").path
        XCTAssertFalse(FileManager.default.fileExists(atPath: chipPath),
                       "Keyboard/Views/WhatsNewChipView.swift must not exist (MOR-400)")
    }

    func testNoKeyboardCodePathInstallsOrReadsAWhatsNewPromotion() throws {
        for source in try keyboardSwiftSources() {
            let text = try String(contentsOf: source, encoding: .utf8)
            for forbidden in ["WhatsNewChip", "installWhatsNewChip", "refreshWhatsNewChip", "WhatsNew."] {
                XCTAssertFalse(text.contains(forbidden),
                               "\(source.lastPathComponent) references `\(forbidden)` — the keyboard must not show a What's New promotion (MOR-400)")
            }
        }
    }

    func testProjectHasNoWhatsNewChipBuildEntry() throws {
        let pbxproj = try String(contentsOf: repoRoot.appendingPathComponent("NumPad.xcodeproj/project.pbxproj"),
                                 encoding: .utf8)
        XCTAssertFalse(pbxproj.contains("WhatsNewChipView.swift"),
                       "project.pbxproj still compiles WhatsNewChipView.swift (MOR-400)")
    }

    /// The removal must not take the in-app announcement paths with it.
    func testInAppSheetAndNotificationPathsRemain() {
        XCTAssertEqual(WhatsNew.deepLinkURLString, "numpad://whats-new")
        XCTAssertTrue(WhatsNew.matchesDeepLink(URL(string: WhatsNew.deepLinkURLString)!))
        XCTAssertTrue(WhatsNew.shouldPresent(lastSeen: nil, current: WhatsNew.cutVersion))
        XCTAssertNotNil(WhatsNewNotification.makeRequest(granted: true, alreadyScheduled: false))
    }
}
