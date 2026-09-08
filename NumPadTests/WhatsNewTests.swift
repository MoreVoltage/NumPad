import XCTest
import UserNotifications
@testable import NumPad

final class WhatsNewGateTests: XCTestCase {
    private var bannerDefaults: UserDefaults!
    private var bannerSuiteName: String!

    override func setUp() {
        super.setUp()
        bannerSuiteName = "whats-new-banner-\(UUID().uuidString)"
        bannerDefaults = UserDefaults(suiteName: bannerSuiteName)!
    }

    override func tearDown() {
        bannerDefaults.removePersistentDomain(forName: bannerSuiteName)
        super.tearDown()
    }

    func testUnseenUpdateShowsBannerUntilDismissed() {
        XCTAssertTrue(WhatsNew.isChipVisible(lastSeen: nil, current: "2.0.3", defaults: bannerDefaults))
        WhatsNew.dismissBanner(defaults: bannerDefaults)
        XCTAssertFalse(WhatsNew.isChipVisible(lastSeen: nil, current: "2.0.3", defaults: bannerDefaults))
    }

    func testDismissalSurvivesReopeningDefaultsAndLaterAppVersions() {
        WhatsNew.dismissBanner(defaults: bannerDefaults)
        let reopened = UserDefaults(suiteName: bannerSuiteName)!
        XCTAssertFalse(WhatsNew.isChipVisible(lastSeen: nil, current: "2.1", defaults: reopened))
        XCTAssertFalse(WhatsNew.isChipVisible(lastSeen: nil, current: "3.0", defaults: reopened))
    }

    func testDismissalDoesNotConsumeRecapOrNotificationChoice() {
        WhatsNew.dismissBanner(defaults: bannerDefaults)
        XCTAssertNil(bannerDefaults.object(forKey: Constants.whatsNewLastSeenVersion.rawValue))
        XCTAssertNil(bannerDefaults.object(forKey: Constants.whatsNewNotificationScheduled.rawValue))
        XCTAssertTrue(WhatsNew.shouldPresent(lastSeen: nil, current: "2.0.3"))
    }

    func testSeenRecapOrOlderAppHidesUndismissedBanner() {
        XCTAssertFalse(WhatsNew.isChipVisible(lastSeen: "2.0.3", current: "2.1", defaults: bannerDefaults))
        XCTAssertFalse(WhatsNew.isChipVisible(lastSeen: nil, current: "2.0.2", defaults: bannerDefaults))
    }

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

final class UpdateNotificationTests: XCTestCase {
    func testRegistrationRequiresExplicitConsentAndOSPermission() {
        for status in [UNAuthorizationStatus.notDetermined, .denied, .authorized, .provisional, .ephemeral] {
            XCTAssertFalse(UpdateNotificationPolicy.canRegister(optedIn: false, authorization: status))
        }
        XCTAssertFalse(UpdateNotificationPolicy.canRegister(optedIn: true, authorization: .denied))
        XCTAssertFalse(UpdateNotificationPolicy.canRegister(optedIn: true, authorization: .notDetermined))
        XCTAssertTrue(UpdateNotificationPolicy.canRegister(optedIn: true, authorization: .authorized))
        XCTAssertTrue(UpdateNotificationPolicy.canRegister(optedIn: true, authorization: .provisional))
        XCTAssertEqual(UpdateNotificationPolicy.authorizationOptions, [.alert, .sound])
    }

    func testCampaignDefaultsToTheAppStoreAndAllowsExplicitRecap() {
        XCTAssertEqual(UpdateNotificationPolicy.destination(identifier: "remote", userInfo: ["kind": "numpad_update"])?.absoluteString, "numpad://app-store")
        XCTAssertEqual(UpdateNotificationPolicy.destination(identifier: "remote", userInfo: ["kind": "numpad_update", "deeplink": "numpad://whats-new"])?.absoluteString, "numpad://whats-new")
        XCTAssertEqual(AppDeepLink.parse(URL(string: "numpad://app-store")!), .appStore)
    }

    func testRemoteMessagesCannotRouteToExternalDebugOrPurchaseURLs() {
        for route in ["https://example.com", "numpad://debug/entitle?pro=1", "numpad://store-preview", "numpad://whats-new?unexpected=1"] {
            XCTAssertNil(UpdateNotificationPolicy.destination(identifier: "remote", userInfo: ["kind": "numpad_update", "deeplink": route]))
        }
        XCTAssertNil(UpdateNotificationPolicy.destination(identifier: "remote", userInfo: [:]))
        XCTAssertNil(UpdateNotificationPolicy.destination(identifier: "remote", userInfo: ["kind": "other", "deeplink": "numpad://whats-new"]))
    }

    func testOldLocalReminderStillOpensTheRecap() {
        XCTAssertEqual(UpdateNotificationPolicy.destination(identifier: WhatsNewNotification.requestID, userInfo: [:])?.absoluteString, WhatsNew.deepLinkURLString)
    }
}

private final class ControlledUpdateMessagingClient: UpdateMessagingClient {
    var tokenRequests: [(String?, Error?) -> Void] = []
    var subscriptions: [(String, (Error?) -> Void)] = []
    var deletions: [(Error?) -> Void] = []
    func token(completion: @escaping (String?, Error?) -> Void) { tokenRequests.append(completion) }
    func subscribe(topic: String, completion: @escaping (Error?) -> Void) { subscriptions.append((topic, completion)) }
    func deleteToken(completion: @escaping (Error?) -> Void) { deletions.append(completion) }
}

final class UpdateNotificationEnrollmentTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!
    private var client: ControlledUpdateMessagingClient!
    private var enrollment: UpdateNotificationEnrollment!
    private let failure = NSError(domain: "notification-tests", code: 1)

    override func setUp() {
        super.setUp()
        suiteName = "update-enrollment-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        client = ControlledUpdateMessagingClient()
        enrollment = UpdateNotificationEnrollment(client: client, defaults: defaults, topic: "test_updates")
    }
    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testFreshOptOutDoesNotCreateAMessagingIdentifier() {
        enrollment.configure(enabled: false, apnsReady: false)
        XCTAssertTrue(client.tokenRequests.isEmpty)
        XCTAssertTrue(client.subscriptions.isEmpty)
        XCTAssertTrue(client.deletions.isEmpty)
        XCTAssertEqual(enrollment.state, .off)
    }

    func testEnrollmentWaitsForAPNsThenForSuccessfulTopicSubscription() {
        enrollment.configure(enabled: true, apnsReady: false)
        XCTAssertTrue(client.tokenRequests.isEmpty)
        enrollment.configure(enabled: true, apnsReady: true)
        XCTAssertEqual(client.tokenRequests.count, 1)
        client.tokenRequests[0]("token-a", nil)
        XCTAssertEqual(client.subscriptions.map { $0.0 }, ["test_updates"])
        XCTAssertEqual(enrollment.state, .connecting)
        client.subscriptions[0].1(nil)
        XCTAssertEqual(enrollment.state, .ready)
        enrollment.configure(enabled: true, apnsReady: true)
        XCTAssertEqual(client.subscriptions.count, 1)
    }

    func testOptOutDuringTokenRequestDeletesInsteadOfSubscribing() {
        enrollment.configure(enabled: true, apnsReady: true)
        enrollment.configure(enabled: false, apnsReady: false)
        client.tokenRequests[0]("late-token", nil)
        XCTAssertTrue(client.subscriptions.isEmpty)
        XCTAssertEqual(client.deletions.count, 1)
        client.deletions[0](nil)
        XCTAssertNil(enrollment.token)
        XCTAssertEqual(enrollment.state, .off)
    }

    func testOptOutDuringSubscriptionWinsOverItsLateSuccess() {
        enrollment.configure(enabled: true, apnsReady: true)
        client.tokenRequests[0]("token-a", nil)
        enrollment.configure(enabled: false, apnsReady: false)
        client.subscriptions[0].1(nil)
        XCTAssertEqual(client.deletions.count, 1)
        client.deletions[0](nil)
        XCTAssertEqual(enrollment.state, .off)
    }

    func testReenableDuringDeletionWaitsAndObtainsANewToken() {
        enrollment.configure(enabled: true, apnsReady: true)
        client.tokenRequests[0]("token-a", nil)
        client.subscriptions[0].1(nil)
        enrollment.configure(enabled: false, apnsReady: false)
        enrollment.configure(enabled: true, apnsReady: true)
        XCTAssertEqual(client.tokenRequests.count, 1)
        client.deletions[0](nil)
        XCTAssertEqual(client.tokenRequests.count, 2)
        XCTAssertNil(enrollment.token)
    }

    func testFailedOptOutCleanupSurvivesProcessRestart() {
        enrollment.configure(enabled: true, apnsReady: true)
        enrollment.configure(enabled: false, apnsReady: false)
        client.tokenRequests[0]("late-token", nil)
        client.deletions[0](failure)
        let relaunched = UpdateNotificationEnrollment(client: client,
            defaults: UserDefaults(suiteName: suiteName)!, topic: "test_updates")
        relaunched.configure(enabled: false, apnsReady: false)
        XCTAssertEqual(client.deletions.count, 2)
        client.deletions[1](nil)
        XCTAssertFalse(defaults.bool(forKey: Constants.updateNotificationsCleanupRequired.rawValue))
    }

    func testTokenRefreshResubscribesAndOldFetchCannotOverwriteIt() {
        enrollment.configure(enabled: true, apnsReady: true)
        enrollment.tokenDidChange("new-token")
        client.tokenRequests[0]("old-token", nil)
        XCTAssertEqual(enrollment.token, "new-token")
        client.subscriptions[0].1(nil)
        enrollment.tokenDidChange("newer-token")
        XCTAssertEqual(client.subscriptions.count, 2)
        XCTAssertEqual(enrollment.state, .connecting)
        client.subscriptions[1].1(nil)
        XCTAssertEqual(enrollment.state, .ready)
    }

    func testSubscriptionFailureNeverReportsReadyAndCanRetry() {
        enrollment.configure(enabled: true, apnsReady: true)
        client.tokenRequests[0]("token-a", nil)
        client.subscriptions[0].1(failure)
        XCTAssertEqual(enrollment.state, .failed)
        enrollment.retry()
        XCTAssertEqual(client.subscriptions.count, 2)
        client.subscriptions[1].1(nil)
        XCTAssertEqual(enrollment.state, .ready)
    }

    func testMovingFromBetaToProductionRemovesTheOldAudienceFirst() {
        enrollment.configure(enabled: true, apnsReady: true)
        client.tokenRequests[0]("beta-token", nil)
        client.subscriptions[0].1(nil)
        let production = UpdateNotificationEnrollment(client: client, defaults: defaults, topic: "production_updates")
        production.configure(enabled: true, apnsReady: true)
        XCTAssertEqual(client.deletions.count, 1)
        XCTAssertEqual(client.tokenRequests.count, 1)
        client.deletions[0](nil)
        client.tokenRequests[1]("production-token", nil)
        XCTAssertEqual(client.subscriptions.last?.0, "production_updates")
    }
}
