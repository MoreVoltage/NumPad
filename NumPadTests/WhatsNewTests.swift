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
