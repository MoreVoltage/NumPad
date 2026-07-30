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

    /// Phone idiom embeds the Studio tab shell while preserving the shared lifecycle root.
    func test_phoneShellEmbedsStudioTabsUnderViewController() {
        let host = PhoneShellViewController()
        host.loadViewIfNeeded()

        XCTAssertNotNil(host.studioTabs, "Phone shell must embed the Studio tab shell")
        XCTAssertEqual(host.studioTabs?.viewControllers?.count, 3)
        XCTAssertNil(host.iPadWorkspace, "iPad workspace must not be installed on phone")
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
