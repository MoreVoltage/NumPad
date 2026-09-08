import XCTest
import UIKit
@testable import NumPad

#if DEBUG
final class DebugDeepLinkRouteTests: XCTestCase {
    private func url(_ string: String) -> URL {
        URL(string: string)!
    }

    // MARK: entitle

    func testEntitleProOn() {
        XCTAssertEqual(DebugDeepLinkRoute.parse(url("numpad://debug/entitle?pro=1")), .entitlePro(true))
    }

    func testEntitleProOff() {
        XCTAssertEqual(DebugDeepLinkRoute.parse(url("numpad://debug/entitle?pro=0")), .entitlePro(false))
    }

    func testEntitleMissingQueryReturnsNil() {
        XCTAssertNil(DebugDeepLinkRoute.parse(url("numpad://debug/entitle")))
    }

    func testEntitleInvalidValueReturnsNil() {
        XCTAssertNil(DebugDeepLinkRoute.parse(url("numpad://debug/entitle?pro=yes")))
    }

    // MARK: preset

    func testPresetSmall() {
        XCTAssertEqual(DebugDeepLinkRoute.parse(url("numpad://debug/preset?value=small")), .heightPreset(.small))
    }

    func testPresetRegular() {
        XCTAssertEqual(DebugDeepLinkRoute.parse(url("numpad://debug/preset?value=regular")), .heightPreset(.regular))
    }

    func testPresetTall() {
        XCTAssertEqual(DebugDeepLinkRoute.parse(url("numpad://debug/preset?value=tall")), .heightPreset(.tall))
    }

    func testPresetKiosk() {
        XCTAssertEqual(DebugDeepLinkRoute.parse(url("numpad://debug/preset?value=kiosk")), .heightPreset(.kiosk))
    }

    func testPresetInvalidValueReturnsNil() {
        XCTAssertNil(DebugDeepLinkRoute.parse(url("numpad://debug/preset?value=huge")))
    }

    func testPresetMissingValueReturnsNil() {
        XCTAssertNil(DebugDeepLinkRoute.parse(url("numpad://debug/preset")))
    }

    // MARK: screen routes

    func testHeightScreen() {
        XCTAssertEqual(DebugDeepLinkRoute.parse(url("numpad://debug/height")), .heightScreen)
    }

    func testCustomKeyboardEditor() {
        XCTAssertEqual(DebugDeepLinkRoute.parse(url("numpad://debug/editor")), .customKeyboardEditor)
    }

    func testTypingSurface() {
        XCTAssertEqual(DebugDeepLinkRoute.parse(url("numpad://debug/typing")), .typingSurface)
    }

    func testFeaturesGuide() {
        XCTAssertEqual(DebugDeepLinkRoute.parse(url("numpad://debug/guide")), .featuresGuide)
    }

    // MARK: rejection

    func testNonDebugHostReturnsNil() {
        XCTAssertNil(DebugDeepLinkRoute.parse(url("numpad://store-preview")))
    }

    func testUnknownDebugPathReturnsNil() {
        XCTAssertNil(DebugDeepLinkRoute.parse(url("numpad://debug/unknown")))
    }

    // MARK: parseAll(fromLaunchArguments:)

    func testParseAllReadsASingleDebugRoutePair() {
        let routes = DebugDeepLinkRoute.parseAll(fromLaunchArguments: ["-debugRoute", "height"])
        XCTAssertEqual(routes, [.heightScreen])
    }

    func testParseAllCombinesMultiplePairsInOrder() {
        let args = ["-debugRoute", "entitle?pro=1", "-debugRoute", "preset?value=kiosk", "-debugRoute", "typing"]
        let routes = DebugDeepLinkRoute.parseAll(fromLaunchArguments: args)
        XCTAssertEqual(routes, [.entitlePro(true), .heightPreset(.kiosk), .typingSurface])
    }

    func testParseAllIgnoresUnrelatedLaunchArguments() {
        let args = ["-someOtherFlag", "1", "-debugRoute", "guide", "-skipOnboarding"]
        let routes = DebugDeepLinkRoute.parseAll(fromLaunchArguments: args)
        XCTAssertEqual(routes, [.featuresGuide])
    }

    func testParseAllSkipsAMalformedPairButKeepsParsingAfterIt() {
        let args = ["-debugRoute", "preset?value=huge", "-debugRoute", "editor"]
        let routes = DebugDeepLinkRoute.parseAll(fromLaunchArguments: args)
        XCTAssertEqual(routes, [.customKeyboardEditor])
    }

    func testParseAllReturnsEmptyWhenDebugRouteHasNoTrailingValue() {
        let routes = DebugDeepLinkRoute.parseAll(fromLaunchArguments: ["-debugRoute"])
        XCTAssertEqual(routes, [])
    }

    func testParseAllReturnsEmptyForArgumentsWithNoDebugRoute() {
        XCTAssertEqual(DebugDeepLinkRoute.parseAll(fromLaunchArguments: ["-skipOnboarding"]), [])
    }

    // MARK: shouldSkipOnboarding

    func testShouldSkipOnboardingReadsProcessArguments() {
        // `shouldSkipOnboarding` reads the live process's arguments (there's no seam to inject a
        // fake ProcessInfo here), so this just pins the behavior against the current test-runner
        // invocation rather than asserting a specific value.
        XCTAssertEqual(DebugDeepLinkRoute.shouldSkipOnboarding, ProcessInfo.processInfo.arguments.contains("-skipOnboarding"))
    }
}

/// Exercise the controller's real post-splash drain, rather than just parsing the route. External
/// navigation and modal presentation are recorded so these tests never leave the test host app.
private final class RecordingUpdateRouteViewController: ViewController {
    let routeDelegate = AppDelegate()
    var blockingModal: UIViewController?
    var appStoreOpens = 0
    var presentedDestinations: [UIViewController] = []
    var onDestination: (() -> Void)?

    override var skipFirstRunFlowsForTesting: Bool { true }
    override var pendingDeepLinkDelegate: AppDelegate? { routeDelegate }
    override var presentedViewController: UIViewController? { blockingModal }

    override func viewDidLoad() {
        // The test controls the splash completion by invoking the real finishLaunch() below.
        view.backgroundColor = .systemBackground
    }

    override func openUpdateAppStore() {
        appStoreOpens += 1
        onDestination?()
    }

    override func present(_ viewControllerToPresent: UIViewController, animated flag: Bool,
                          completion: (() -> Void)? = nil) {
        presentedDestinations.append(viewControllerToPresent)
        completion?()
        onDestination?()
    }
}

final class UpdateNotificationLaunchRouteTests: XCTestCase {
    @MainActor
    private func withController(_ body: (RecordingUpdateRouteViewController, AppDelegate) throws -> Void) throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive })
        let controller = RecordingUpdateRouteViewController()
        let delegate = controller.routeDelegate
        let previousPendingURL = delegate.pendingURL
        let previousKeyWindow = scene.windows.first { $0.isKeyWindow }
        let defaults = UserDefaults.group
        let savedKeys = [Constants.rcApplied.rawValue, Constants.onboardingShown.rawValue,
                         Constants.whatsNewLastSeenVersion.rawValue]
        let savedValues = savedKeys.map { defaults.object(forKey: $0) }
        defaults.set(true, forKey: Constants.rcApplied.rawValue)
        delegate.pendingURL = nil

        let window = UIWindow(windowScene: scene)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer {
            delegate.pendingURL = nil
            controller.handlePendingDeepLink() // cancel any queued retry before restoring state
            window.isHidden = true
            window.rootViewController = nil
            previousKeyWindow?.makeKeyAndVisible()
            for (key, value) in zip(savedKeys, savedValues) {
                if let value { defaults.set(value, forKey: key) }
                else { defaults.removeObject(forKey: key) }
            }
            delegate.pendingURL = previousPendingURL
        }
        try body(controller, delegate)
    }

    @MainActor
    func testColdAppStoreTapDrainsWhenSplashCompletesWithoutAnotherForeground() throws {
        try withController { controller, delegate in
            let route = URL(string: "numpad://app-store")!
            delegate.pendingURL = route
            XCTAssertFalse(controller.handlePendingDeepLink())
            XCTAssertEqual(delegate.pendingURL, route)
            XCTAssertEqual(controller.appStoreOpens, 0)

            controller.finishLaunch()

            XCTAssertEqual(controller.appStoreOpens, 1)
            XCTAssertNil(delegate.pendingURL)
            XCTAssertFalse(controller.handlePendingDeepLink())
            XCTAssertEqual(controller.appStoreOpens, 1)
        }
    }

    @MainActor
    func testColdWhatsNewTapPresentsWhenSplashCompletes() throws {
        try withController { controller, delegate in
            delegate.pendingURL = URL(string: "numpad://whats-new")!
            XCTAssertFalse(controller.handlePendingDeepLink())
            XCTAssertTrue(controller.presentedDestinations.isEmpty)

            controller.finishLaunch()

            XCTAssertEqual(controller.presentedDestinations.count, 1)
            XCTAssertTrue(controller.presentedDestinations.first is WhatsNewViewController)
            XCTAssertNil(delegate.pendingURL)
        }
    }

    @MainActor
    func testColdTapWaitsForModalAndRetriesAfterDismissalWithoutForegrounding() throws {
        try withController { controller, delegate in
            let opened = expectation(description: "Waiting notification opens after modal dismissal")
            controller.onDestination = { opened.fulfill() }
            controller.blockingModal = UIViewController()
            let route = URL(string: "numpad://app-store")!
            delegate.pendingURL = route

            controller.finishLaunch()

            XCTAssertEqual(controller.appStoreOpens, 0)
            XCTAssertEqual(delegate.pendingURL, route)
            // Page-sheet dismissal need not call the root controller's viewDidAppear. Clearing the
            // blocker without posting a lifecycle event must still allow the queued tap to run.
            controller.blockingModal = nil
            wait(for: [opened], timeout: 2)
            XCTAssertEqual(controller.appStoreOpens, 1)
            XCTAssertNil(delegate.pendingURL)
        }
    }

    @MainActor
    func testWarmWhatsNewTapWaitsForAnExistingSheetToClose() throws {
        try withController { controller, delegate in
            controller.finishLaunch()
            let presented = expectation(description: "Waiting recap presents after sheet dismissal")
            controller.onDestination = { presented.fulfill() }
            controller.blockingModal = UIViewController()
            let route = URL(string: "numpad://whats-new")!
            delegate.pendingURL = route

            XCTAssertFalse(controller.handlePendingDeepLink())
            XCTAssertEqual(delegate.pendingURL, route)
            XCTAssertTrue(controller.presentedDestinations.isEmpty)

            controller.blockingModal = nil
            wait(for: [presented], timeout: 2)
            XCTAssertEqual(controller.presentedDestinations.count, 1)
            XCTAssertTrue(controller.presentedDestinations.first is WhatsNewViewController)
            XCTAssertNil(delegate.pendingURL)
        }
    }
}

final class PendingDeepLinkDispatchTests: XCTestCase {
    @MainActor
    func testSettingAURLNotifiesImmediatelyAndDrainingDoesNotReenter() {
        let delegate = AppDelegate()
        let route = URL(string: "numpad://whats-new")!
        var received: [URL] = []
        var notificationCount = 0
        let observer = NotificationCenter.default.addObserver(forName: .numpadPendingDeepLink,
            object: delegate, queue: nil) { _ in
                notificationCount += 1
                if let url = delegate.pendingURL {
                    received.append(url)
                    delegate.pendingURL = nil
                }
            }
        defer { NotificationCenter.default.removeObserver(observer) }

        delegate.pendingURL = route

        XCTAssertEqual(received, [route])
        XCTAssertEqual(notificationCount, 1)
        XCTAssertNil(delegate.pendingURL)
        // Opening the same destination again is a new action, even if its URL is unchanged.
        delegate.pendingURL = route
        XCTAssertEqual(received, [route, route])
        XCTAssertEqual(notificationCount, 2)
        XCTAssertNil(delegate.pendingURL)
    }

    @MainActor
    func testLegacyURLIngressNotifiesWithoutWaitingForAnActivation() {
        let delegate = AppDelegate()
        let route = URL(string: "numpad://app-store")!
        var received: [URL] = []
        let observer = NotificationCenter.default.addObserver(forName: .numpadPendingDeepLink,
            object: delegate, queue: nil) { _ in
                if let url = delegate.pendingURL { received.append(url) }
            }
        defer { NotificationCenter.default.removeObserver(observer) }

        XCTAssertTrue(delegate.application(UIApplication.shared, open: route))
        XCTAssertEqual(received, [route])
        XCTAssertEqual(delegate.pendingURL, route)
        XCTAssertFalse(delegate.application(UIApplication.shared, open: URL(string: "https://example.com")!))
        XCTAssertEqual(received, [route])
    }
}
#endif
