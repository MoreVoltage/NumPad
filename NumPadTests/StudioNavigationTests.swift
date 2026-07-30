//
//  StudioNavigationTests.swift
//  NumPadTests
//

import XCTest
@testable import NumPad

final class StudioNavigationTests: XCTestCase {
    func test_phoneShellExposesOnlyKeyboardFeaturesAndHelpWithKeyboardSelected() {
        let shell = StudioNavigationFactory.makePhoneShell()

        XCTAssertEqual(shell.viewControllers?.compactMap(\.tabBarItem.title), ["Keyboard", "Features", "Help"])
        XCTAssertEqual(shell.selectedIndex, 0)
        XCTAssertEqual(shell.viewControllers?.count, 3)
        XCTAssertTrue(shell.selectedViewController is UINavigationController)
        XCTAssertTrue((shell.selectedViewController as? UINavigationController)?.viewControllers.first is KeyboardStudioViewController)
    }

    func test_phoneShellWrapsEveryDestinationInNavigationController() {
        let shell = StudioNavigationFactory.makePhoneShell()

        XCTAssertEqual(shell.viewControllers?.count, 3)
        for controller in shell.viewControllers ?? [] {
            XCTAssertTrue(controller is UINavigationController)
        }
    }

    func test_phoneShellDoesNotExposeDashboardAsATabDestination() {
        let shell = StudioNavigationFactory.makePhoneShell()

        XCTAssertFalse(shell.viewControllers?.contains { controller in
            (controller as? UINavigationController)?.viewControllers.contains {
                $0 is DashboardViewController
            } == true
        } ?? true)
    }

    func test_keyboardGearPresentsFunctionalAdvancedNavigationSurface() {
        let keyboard = KeyboardStudioViewController()
        let window = makeVisibleWindow(rootViewController: UINavigationController(rootViewController: keyboard))
        keyboard.loadViewIfNeeded()

        guard
            let item = keyboard.navigationItem.rightBarButtonItem,
            let target = item.target as? NSObject,
            let action = item.action
        else {
            return XCTFail("Keyboard Studio must provide a functional Advanced gear action")
        }

        _ = target.perform(action)

        let presented = keyboard.presentedViewController as? UINavigationController
        XCTAssertTrue(presented?.viewControllers.first is AdvancedStudioViewController)
        XCTAssertEqual(presented?.viewControllers.first?.title, "Advanced")
        XCTAssertNotNil(
            view(withAccessibilityIdentifier: "studio.advanced.saved-setups", in: presented?.viewControllers.first?.view),
            "Advanced must expose a working Saved setups destination rather than a no-op surface."
        )
        keyboard.dismiss(animated: false)
        window.isHidden = true
    }

    func test_disabledKeyboardStatusActionUsesStableOpenSetupIdentifier() {
        let defaults = UserDefaults.standard
        let key = "AppleKeyboards"
        let previousKeyboards = defaults.object(forKey: key)
        defer {
            if let previousKeyboards {
                defaults.set(previousKeyboards, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }
        defaults.set([], forKey: key)
        XCTAssertFalse(Keyboard.isKeyboardEnabled, "Precondition: an empty enabled-keyboards list must show the setup repair action.")

        let keyboard = KeyboardStudioViewController()
        keyboard.loadViewIfNeeded()

        let hero = view(withAccessibilityIdentifier: "studio.keyboard.status", in: keyboard.view)
            as? StudioStatusHeroView
        XCTAssertEqual(hero?.actionAccessibilityIdentifier, "studio.keyboard.openSetup")
        XCTAssertNotNil(
            view(withAccessibilityIdentifier: "studio.keyboard.openSetup", in: keyboard.view),
            "The visible Open setup action needs its own stable identifier, not only an identifier on its hero."
        )
    }

    private func makeVisibleWindow(rootViewController: UIViewController) -> UIWindow {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = rootViewController
        window.makeKeyAndVisible()
        rootViewController.view.layoutIfNeeded()
        return window
    }

    private func view(withAccessibilityIdentifier identifier: String, in root: UIView?) -> UIView? {
        guard let root else { return nil }
        if root.accessibilityIdentifier == identifier { return root }
        for child in root.subviews {
            if let match = view(withAccessibilityIdentifier: identifier, in: child) {
                return match
            }
        }
        return nil
    }
}
