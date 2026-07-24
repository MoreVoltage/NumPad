//
//  DeepLinkRouterTests.swift
//  NumPadTests
//

import XCTest
@testable import NumPad

final class DeepLinkRouterTests: XCTestCase {
    func test_parseStorePreviewWithSource() {
        let url = URL(string: "numpad://store-preview?source=key_lock")!
        XCTAssertEqual(DeepLinkRouter.parse(url), .storePreview(source: "key_lock"))
    }

    func test_parseStorePreviewDefaultSource() {
        let url = URL(string: "numpad://store-preview")!
        XCTAssertEqual(DeepLinkRouter.parse(url), .storePreview(source: "deep_link"))
    }

    func test_parseRejectsUnknownSchemeAndHost() {
        XCTAssertNil(DeepLinkRouter.parse(URL(string: "https://example.com/store-preview")!))
        XCTAssertNil(DeepLinkRouter.parse(URL(string: "numpad://unknown")!))
    }

    func test_parseAcceptsRegisteredProfileDocumentFileURL() {
        let url = URL(fileURLWithPath: "/private/tmp/Fleet.numpadprofile")
        XCTAssertEqual(DeepLinkRouter.parse(url), .profileDocument(url))
        XCTAssertNil(DeepLinkRouter.parse(URL(fileURLWithPath: "/private/tmp/Fleet.json")))
    }

    func test_profileDocumentRoutePresentsProfilesWorkflow() {
        let host = UIViewController()
        let navigation = UINavigationController(rootViewController: host)
        let url = URL(fileURLWithPath: "/private/tmp/Fleet.numpadprofile")

        DeepLinkRouter.present(.profileDocument(url), from: host)

        XCTAssertTrue(navigation.topViewController is ProfilesViewController)
    }

    func test_activeNavigationPrefersSplitSecondary() {
        let host = UIViewController()
        let split = UISplitViewController(style: .doubleColumn)
        let primary = UINavigationController(rootViewController: UIViewController())
        let secondary = UINavigationController(rootViewController: UIViewController())
        split.setViewController(primary, for: .primary)
        split.setViewController(secondary, for: .secondary)
        host.addChild(split)
        host.view.addSubview(split.view)
        split.didMove(toParent: host)

        XCTAssertTrue(DeepLinkRouter.activeNavigationController(from: host) === secondary)
    }

    func test_activeNavigationTraversesStoryboardRootNavigationLifecycleHostAndSplitDetail() {
        let lifecycleHost = PadDeepLinkLifecycleHost()
        let storyboardRoot = UINavigationController(rootViewController: lifecycleHost)
        storyboardRoot.loadViewIfNeeded()
        lifecycleHost.loadViewIfNeeded()

        let secondary = lifecycleHost.iPadSplit?.viewController(for: .secondary)
            as? UINavigationController
        XCTAssertNotNil(secondary)
        XCTAssertTrue(
            DeepLinkRouter.activeNavigationController(from: storyboardRoot) === secondary
        )
    }

    func test_coldRoutePushesThroughRootNavigationIntoSplitDetail() {
        let lifecycleHost = PadDeepLinkLifecycleHost()
        let storyboardRoot = UINavigationController(rootViewController: lifecycleHost)
        storyboardRoot.loadViewIfNeeded()
        lifecycleHost.loadViewIfNeeded()

        DeepLinkRouter.present(.storePreview(source: "cold"), from: storyboardRoot)

        let secondary = lifecycleHost.iPadSplit?.viewController(for: .secondary)
            as? UINavigationController
        XCTAssertTrue(secondary?.topViewController is StoreViewController)
        XCTAssertEqual(
            (secondary?.topViewController as? StoreViewController)?.source,
            "cold"
        )
        XCTAssertTrue(storyboardRoot.topViewController === lifecycleHost)
    }

    func test_warmRouteUsesVisibleSplitSecondaryAfterPriorNavigation() {
        let lifecycleHost = PadDeepLinkLifecycleHost()
        let storyboardRoot = UINavigationController(rootViewController: lifecycleHost)
        storyboardRoot.loadViewIfNeeded()
        lifecycleHost.loadViewIfNeeded()
        guard let secondary = lifecycleHost.iPadSplit?.viewController(for: .secondary)
                as? UINavigationController else {
            return XCTFail("Expected split secondary navigation")
        }
        secondary.pushViewController(UIViewController(), animated: false)
        let profileURL = URL(fileURLWithPath: "/private/tmp/Warm.numpadprofile")

        DeepLinkRouter.present(.profileDocument(profileURL), from: storyboardRoot)

        XCTAssertTrue(secondary.topViewController is ProfilesViewController)
        XCTAssertTrue(storyboardRoot.topViewController === lifecycleHost)
    }

    func test_pendingProfileAndStoreRoutesRemainQueuedBehindStandaloneModal() {
        let routes: [(URL, UIViewController.Type)] = [
            (
                URL(string: "numpad://store-preview?source=modal_queue")!,
                StoreViewController.self
            ),
            (
                URL(fileURLWithPath: "/private/tmp/Queued.numpadprofile"),
                ProfilesViewController.self
            )
        ]

        for (url, expectedType) in routes {
            let host = UIViewController()
            let navigation = UINavigationController(rootViewController: host)
            let window = makeVisibleWindow(rootViewController: navigation)
            let modal = UIViewController()
            navigation.present(modal, animated: false)
            XCTAssertTrue(navigation.presentedViewController === modal)

            var pendingURL: URL? = url
            XCTAssertFalse(DeepLinkRouter.drainPending(&pendingURL, from: host))
            XCTAssertEqual(pendingURL, url)
            XCTAssertTrue(navigation.topViewController === host)

            let dismissed = expectation(description: "Standalone modal dismissed")
            navigation.dismiss(animated: false) {
                dismissed.fulfill()
            }
            wait(for: [dismissed], timeout: 1)
            XCTAssertTrue(DeepLinkRouter.drainPending(&pendingURL, from: host))
            XCTAssertNil(pendingURL)
            XCTAssertTrue(navigation.topViewController?.isKind(of: expectedType) == true)
            window.isHidden = true
        }
    }

    func test_pendingProfileAndStoreRoutesUsePresentedNavigationStack() {
        let routes: [(URL, UIViewController.Type)] = [
            (
                URL(string: "numpad://store-preview?source=presented_navigation")!,
                StoreViewController.self
            ),
            (
                URL(fileURLWithPath: "/private/tmp/Presented.numpadprofile"),
                ProfilesViewController.self
            )
        ]

        for (url, expectedType) in routes {
            let host = UIViewController()
            let navigation = UINavigationController(rootViewController: host)
            let presentedRoot = UIViewController()
            let presentedNavigation = UINavigationController(
                rootViewController: presentedRoot
            )
            let window = makeVisibleWindow(rootViewController: navigation)
            navigation.present(presentedNavigation, animated: false)
            XCTAssertTrue(navigation.presentedViewController === presentedNavigation)

            var pendingURL: URL? = url
            XCTAssertTrue(DeepLinkRouter.drainPending(&pendingURL, from: host))
            XCTAssertNil(pendingURL)
            XCTAssertTrue(
                presentedNavigation.topViewController?.isKind(of: expectedType) == true
            )
            XCTAssertTrue(navigation.topViewController === host)

            navigation.dismiss(animated: false)
            window.isHidden = true
        }
    }

    #if DEBUG
    func test_uiTestResetClearsWholeAppGroupAndPostsOnce() {
        let suite = "DeepLinkRouterTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("stale-profile", forKey: Constants.activeKeyboardProfileID.rawValue)
        defaults.set(true, forKey: "kioskTryItConfirmed")
        defaults.set(Data([0x01]), forKey: Constants.keyboardProfiles.rawValue)
        var posts = 0

        DeepLinkRouter.applyUITestAppGroupReset(defaults: defaults) {
            posts += 1
        }

        XCTAssertNil(defaults.object(forKey: Constants.activeKeyboardProfileID.rawValue))
        XCTAssertNil(defaults.object(forKey: "kioskTryItConfirmed"))
        XCTAssertNil(defaults.object(forKey: Constants.keyboardProfiles.rawValue))
        XCTAssertEqual(posts, 1)
    }

    func test_uiTestAppGroupResetRemovesTypingQualityArtifacts() throws {
        let suite = "DeepLinkRouterArtifactsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DeepLinkRouterArtifactsTests.\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: directory) }
        let counterURL = directory.appendingPathComponent("typingQualityCounters.json")
        let lockURL = counterURL.appendingPathExtension("lock")
        try Data([0x01]).write(to: counterURL)
        try Data([0x02]).write(to: lockURL)

        DeepLinkRouter.applyUITestAppGroupReset(
            defaults: defaults,
            artifactURLs: [counterURL, lockURL]
        ) {}

        XCTAssertFalse(FileManager.default.fileExists(atPath: counterURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: lockURL.path))
    }

    func test_uiTestResetLaunchArgumentClearsStateBeforeStartupWork() {
        let suite = "DeepLinkRouterLaunchTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("stale-profile", forKey: Constants.activeKeyboardProfileID.rawValue)
        var posts = 0

        let handled = DeepLinkRouter.applyUITestAppGroupResetIfRequested(
            arguments: ["NumPad", "-resetUITestAppGroup"],
            defaults: defaults
        ) {
            posts += 1
        }

        XCTAssertTrue(handled)
        XCTAssertNil(defaults.object(forKey: Constants.activeKeyboardProfileID.rawValue))
        XCTAssertEqual(posts, 1)
    }

    func test_uiTestResetLaunchArgumentDoesNothingWhenAbsent() {
        let suite = "DeepLinkRouterLaunchTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("keep", forKey: Constants.activeKeyboardProfileID.rawValue)
        var posts = 0

        let handled = DeepLinkRouter.applyUITestAppGroupResetIfRequested(
            arguments: ["NumPad"],
            defaults: defaults
        ) {
            posts += 1
        }

        XCTAssertFalse(handled)
        XCTAssertEqual(
            defaults.string(forKey: Constants.activeKeyboardProfileID.rawValue),
            "keep"
        )
        XCTAssertEqual(posts, 0)
    }
    #endif

    private func makeVisibleWindow(rootViewController: UIViewController) -> UIWindow {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 1_024, height: 768))
        window.rootViewController = rootViewController
        window.makeKeyAndVisible()
        rootViewController.view.layoutIfNeeded()
        return window
    }
}

private final class PadDeepLinkLifecycleHost: ViewController {
    override var preferredContentShellIdiom: UIUserInterfaceIdiom { .pad }
}
