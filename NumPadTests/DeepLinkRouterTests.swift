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

    func test_onlyExplicitPresentedNavigationContainersAreRouteable() {
        XCTAssertTrue(
            DeepLinkRouter.isRouteablePresentedContainer(UINavigationController())
        )
        XCTAssertTrue(
            DeepLinkRouter.isRouteablePresentedContainer(
                UISplitViewController(style: .doubleColumn)
            )
        )
        XCTAssertFalse(
            DeepLinkRouter.isRouteablePresentedContainer(
                UIAlertController(title: nil, message: nil, preferredStyle: .alert)
            )
        )
        XCTAssertFalse(
            DeepLinkRouter.isRouteablePresentedContainer(
                UIActivityViewController(
                    activityItems: ["NumPad"],
                    applicationActivities: nil
                )
            )
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

    func test_dismissingStandaloneChildModalAutomaticallyDrainsProfileAndStoreRoutes() {
        let routes: [(URL, UIViewController.Type, (UIViewController) -> UIViewController)] = [
            (
                URL(string: "numpad://store-preview?source=modal_queue")!,
                StoreViewController.self,
                { _ in
                    let sheet = UIViewController()
                    sheet.modalPresentationStyle = .formSheet
                    return sheet
                }
            ),
            (
                URL(fileURLWithPath: "/private/tmp/Queued.numpadprofile"),
                ProfilesViewController.self,
                { _ in
                    UIAlertController(
                        title: "Blocking alert",
                        message: nil,
                        preferredStyle: .alert
                    )
                }
            )
        ]

        for (url, expectedType, makeModal) in routes {
            let host = UIViewController()
            let navigation = UINavigationController(rootViewController: host)
            let window = makeVisibleWindow(rootViewController: navigation)
            let childPresenter = UIViewController()
            host.addChild(childPresenter)
            childPresenter.view.frame = host.view.bounds
            host.view.addSubview(childPresenter.view)
            childPresenter.didMove(toParent: host)
            let modal = makeModal(childPresenter)
            childPresenter.present(modal, animated: false)
            XCTAssertTrue(childPresenter.presentedViewController === modal)
            let delegate = PresentationDelegateSpy()
            if !(modal is UIAlertController) {
                modal.presentationController?.delegate = delegate
            }

            let request = PendingDeepLinkRequest(url: url)
            XCTAssertFalse(DeepLinkRouter.drainPending(request, from: host))
            XCTAssertEqual(request.url, url)
            XCTAssertTrue(navigation.topViewController === host)
            if !(modal is UIAlertController) {
                XCTAssertTrue(modal.presentationController?.delegate === delegate)
            }

            modal.dismiss(animated: false)
            let routeAppeared = XCTNSPredicateExpectation(
                predicate: NSPredicate { _, _ in
                    navigation.topViewController?.isKind(of: expectedType) == true
                },
                object: nil
            )
            wait(for: [routeAppeared], timeout: 2)
            XCTAssertNil(request.url)
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

            let request = PendingDeepLinkRequest(url: url)
            XCTAssertTrue(DeepLinkRouter.drainPending(request, from: host))
            XCTAssertNil(request.url)
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

    func test_uiTestAppGroupResetClearsTypingQualityDataAndPreservesLockFile() throws {
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
        let store = TypingQualityCounterStore(
            fileURL: directory.appendingPathComponent("typingQualityCounters.json")
        )
        TypingQualityCounters.increment(.keyTaps, store: store, by: 3)
        let lockURL = store.fileURL.appendingPathExtension("lock")
        let inodeBefore = try inode(of: lockURL)

        DeepLinkRouter.applyUITestAppGroupReset(
            defaults: defaults,
            typingQualityStore: store
        ) {}

        XCTAssertTrue(TypingQualityCounters.drain(store: store).isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: lockURL.path))
        XCTAssertEqual(try inode(of: lockURL), inodeBefore)
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

    private func inode(of url: URL) throws -> UInt64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes[.systemFileNumber] as? NSNumber)?.uint64Value ?? 0
    }
}

private final class PadDeepLinkLifecycleHost: ViewController {
    override var preferredContentShellIdiom: UIUserInterfaceIdiom { .pad }
}

private final class PresentationDelegateSpy: NSObject, UIAdaptivePresentationControllerDelegate {}
