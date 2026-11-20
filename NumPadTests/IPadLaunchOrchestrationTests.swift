//
//  IPadLaunchOrchestrationTests.swift
//  NumPadTests
//
//  Phase 1: prove iPad cold launch / foreground / deep-link share ViewController
//  lifecycle, and that store-preview presents from the split secondary nav.
//

import XCTest
@testable import NumPad

final class IPadLaunchOrchestrationTests: XCTestCase {
    /// The storyboard initial VC must remain the shared lifecycle coordinator on every idiom —
    /// SceneDelegate must not install the iPad split as the window root.
    func test_storyboardInitialIsLifecycleCoordinator() {
        let storyboard = UIStoryboard(name: "Main", bundle: Bundle(for: ViewController.self))
        let initial = storyboard.instantiateInitialViewController()
        // InteractiveNavigationController wraps ViewController in Main.storyboard.
        if let nav = initial as? UINavigationController {
            XCTAssertTrue(nav.viewControllers.first is ViewController,
                          "Storyboard root nav must host ViewController")
        } else {
            XCTAssertTrue(initial is ViewController,
                          "Storyboard initial must be ViewController (or nav wrapping it)")
        }
    }

    /// On pad idiom, ViewController embeds the Studio workspace and keeps itself as the lifecycle
    /// host (so finishLaunch / StoreKit / CloudSync / counters still run).
    func test_iPadShellEmbedsStudioWorkspaceUnderViewController() {
        let host = PadShellViewController()
        host.loadViewIfNeeded()

        XCTAssertNotNil(host.iPadWorkspace, "iPad shell must embed IPadStudioWorkspaceViewController")
        XCTAssertNil(host.tableView, "Phone HomeViewController must not be installed on iPad")
        XCTAssertTrue(host.children.contains { $0 is IPadStudioWorkspaceViewController })
        XCTAssertFalse(host.children.contains { $0 is IPadSettingsSplitViewController })
    }

    /// Phone idiom embeds the classic Home settings list (not Studio tabs) while preserving
    /// the shared lifecycle root. Studio remains iPad-only via preferredContentShellIdiom.
    func test_phoneShellEmbedsHomeListUnderViewController() {
        let host = PhoneShellViewController()
        host.loadViewIfNeeded()

        XCTAssertNotNil(host.tableView, "Phone shell must embed classic HomeViewController")
        XCTAssertTrue(host.children.contains { $0 is HomeViewController })
        XCTAssertNil(host.studioTabs, "StudioTabBarController must not be the iPhone root")
        XCTAssertNil(host.iPadWorkspace, "iPad workspace must not be installed on phone")
    }

    /// Production path (no idiom override): on an iPhone, the storyboard's initial lifecycle
    /// coordinator must embed the classic Home list and nothing from the Studio tab shell — the
    /// StudioTabBarController must never become (or be embedded under) the iPhone root.
    func test_iPhoneProductionRootIsClassicHomeNotStudioTabBar() throws {
        try XCTSkipIf(UIDevice.current.userInterfaceIdiom != .phone, "iPhone-only assertion")
        let storyboard = UIStoryboard(name: "Main", bundle: Bundle(for: ViewController.self))
        let initial = try XCTUnwrap(storyboard.instantiateInitialViewController())
        XCTAssertFalse(initial is UITabBarController, "window root must not be a tab bar controller")
        let root: ViewController
        if let nav = initial as? UINavigationController {
            root = try XCTUnwrap(nav.viewControllers.first as? ViewController)
        } else {
            root = try XCTUnwrap(initial as? ViewController)
        }
        XCTAssertEqual(root.preferredContentShellIdiom, .phone)
        root.loadViewIfNeeded()

        XCTAssertNotNil(root.tableView, "iPhone root must embed classic HomeViewController")
        XCTAssertNil(root.studioTabs, "StudioTabBarController must not be the iPhone root")
        XCTAssertNil(root.iPadWorkspace)
        var stack: [UIViewController] = [initial]
        while let controller = stack.popLast() {
            XCTAssertFalse(controller is UITabBarController,
                           "\(type(of: controller)) found in the iPhone root hierarchy")
            XCTAssertFalse(controller is IPadStudioWorkspaceViewController)
            stack.append(contentsOf: controller.children)
        }
        XCTAssertNotNil(root.view.viewWithAccessibilityIdentifier("home.demo-field"),
                        "classic Home keeps the Try-the-keyboard demo field")
    }

    /// Source contract: no production launch path builds the Studio phone tab shell.
    func test_noProductionCodeInstallsStudioPhoneShell() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        for path in ["NumPad/Controllers/Base/ViewController.swift", "NumPad/SceneDelegate.swift",
                     "NumPad/AppDelegate.swift", "NumPad/Libraries/DeepLinkRouter.swift"] {
            let source = try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
            XCTAssertFalse(source.contains("makePhoneShell"), "\(path) must not build the Studio phone shell")
            XCTAssertFalse(source.contains("StudioTabBarController()"), "\(path) must not build StudioTabBarController")
        }
    }

    /// `numpad://store-preview` must push StoreViewController onto the visible workspace navigation.
    func test_storePreviewPushesOntoWorkspaceNavigation() {
        let host = UIViewController()
        let workspace = IPadStudioWorkspaceViewController()
        host.addChild(workspace)
        host.view.addSubview(workspace.view)
        workspace.didMove(toParent: host)
        _ = workspace.view

        XCTAssertNotNil(DeepLinkRouter.activeNavigationController(from: host),
                        "Workspace navigation must be discoverable")

        DeepLinkRouter.present(.storePreview(source: "test_source"), from: host)

        let nav = workspace.activeNavigationController
        XCTAssertTrue(nav.topViewController is StoreViewController,
                      "store-preview must present StoreViewController from the active nav")
        if let store = nav.topViewController as? StoreViewController {
            XCTAssertEqual(store.source, "test_source")
        }
    }

    /// Foreground refresh contract: after the first activation, ViewController calls
    /// `StoreManager.refreshEntitlementsOnForeground()` and `CloudSync.pull()`. Documented here
    /// as a source-level contract on the shared coordinator (iPad no longer bypasses it).
    func test_viewControllerForegroundRefreshContract() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("NumPad/Controllers/Base/ViewController.swift")
        let source = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(source.contains("StoreManager.refreshEntitlementsOnForeground()"))
        XCTAssertTrue(source.contains("CloudSync.pull()"))
        XCTAssertTrue(source.contains("LockFunnelCounters.flushIfNeeded()"))
        XCTAssertTrue(source.contains("MathPreviewCounters.flushIfNeeded()"))
        XCTAssertTrue(source.contains("DeepLinkRouter.drainPending"))
        XCTAssertTrue(source.contains("StoreManager.start()"))
        XCTAssertTrue(source.contains("CloudSync.start()"))
    }

    func test_sceneDelegateKeepsSharedRoot() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("NumPad/SceneDelegate.swift")
        let source = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(source.contains("instantiateInitialViewController()"))
        XCTAssertFalse(source.contains("IPadSettingsSplitViewController()"))
        XCTAssertTrue(source.contains("DeepLinkRouter.drainPending"))
    }
}

private final class PadShellViewController: ViewController {
    override var preferredContentShellIdiom: UIUserInterfaceIdiom { .pad }
}

private final class PhoneShellViewController: ViewController {
    override var preferredContentShellIdiom: UIUserInterfaceIdiom { .phone }
}

private extension UIView {
    func viewWithAccessibilityIdentifier(_ identifier: String) -> UIView? {
        if accessibilityIdentifier == identifier { return self }
        for subview in subviews {
            if let match = subview.viewWithAccessibilityIdentifier(identifier) { return match }
        }
        return nil
    }
}
