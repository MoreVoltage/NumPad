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
}

private final class PadDeepLinkLifecycleHost: ViewController {
    override var preferredContentShellIdiom: UIUserInterfaceIdiom { .pad }
}
