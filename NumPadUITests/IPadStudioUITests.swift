//
//  IPadStudioUITests.swift
//  NumPadUITests
//

import XCTest

/// Signed-device coverage for the iPad workspace.  These assertions exercise the live application
/// hierarchy and truthful preview — no controller doubles or source inspection.
final class IPadStudioUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        guard XCUIScreen.main.screenshot().image.size.width >= 700 else {
            throw XCTSkip("iPad Studio coverage requires an iPad simulator")
        }
    }

    func test_iPadStudioLandscapeKeepsDockPinnedWhileChangingDestinationsAndOpeningAdvanced() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = launchNumPad(additionalLaunchArguments: ["-debugStudioKeyboardReady", "1"])
        let dock = app.otherElements["studio.keyboard-dock"]
        XCTAssertTrue(dock.waitForExistence(timeout: 20), "Permanent keyboard dock was not rendered")
        assertDockPinned(dock, in: app)
        attachScreenshot(named: "ipad-studio-landscape-keyboard")

        selectDestination("Features", in: app)
        XCTAssertTrue(app.otherElements["studio.features"].waitForExistence(timeout: 5))
        XCTAssertTrue(dock.exists)
        assertDockPinned(dock, in: app)
        attachScreenshot(named: "ipad-studio-landscape-features")

        selectDestination("Help", in: app)
        XCTAssertTrue(app.otherElements["studio.help"].waitForExistence(timeout: 5))
        XCTAssertTrue(dock.exists)
        assertDockPinned(dock, in: app)
        attachScreenshot(named: "ipad-studio-landscape-help")

        let advanced = app.buttons["studio.ipad.advanced"].firstMatch.exists
            ? app.buttons["studio.ipad.advanced"].firstMatch
            : app.buttons["studio.keyboard.advanced"].firstMatch
        XCTAssertTrue(advanced.waitForExistence(timeout: 5))
        advanced.tap()
        XCTAssertTrue(app.otherElements["studio.advanced"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.otherElements["studio.advanced"].isHittable)
        XCTAssertTrue(dock.isHittable)
        XCTAssertEqual(app.sheets.count, 0, "Advanced must not be a sheet over the permanent dock")
        attachScreenshot(named: "ipad-studio-landscape-advanced")
    }

    func test_iPadStudioShortCompactKioskOverrideKeepsSelectorDestinationAndDockHittableTogether() {
        let app = launchNumPad(
            additionalLaunchArguments: [
                "-debugStudioKeyboardReady", "1",
                "-debugIPadStudioCompact", "1",
                "-debugIPadStudioSafeHeight", "320",
                "-debugIPadStudioKiosk", "1"
            ]
        )
        let dock = app.otherElements["studio.keyboard-dock"]
        XCTAssertTrue(dock.waitForExistence(timeout: 20))
        let selector = app.segmentedControls["studio.ipad.destinations"]
        XCTAssertTrue(selector.waitForExistence(timeout: 5))
        XCTAssertTrue(selector.isHittable)
        XCTAssertEqual(dock.frame.height, 124, accuracy: 1)
        XCTAssertTrue(dock.isHittable)

        let compactAdvanced = app.buttons["studio.ipad.advanced"]
        XCTAssertTrue(compactAdvanced.waitForExistence(timeout: 5))
        compactAdvanced.tap()
        let advanced = app.otherElements["studio.advanced"]
        XCTAssertTrue(advanced.waitForExistence(timeout: 5))
        XCTAssertTrue(advanced.isHittable)
        let destinationControl = app.buttons["studio.advanced.saved-setups"]
        XCTAssertTrue(destinationControl.waitForExistence(timeout: 5))
        let navigationBar = app.navigationBars["Advanced"]
        XCTAssertTrue(navigationBar.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(selector.frame.height, 44)
        XCTAssertGreaterThanOrEqual(navigationBar.frame.minY, selector.frame.maxY + 8)
        XCTAssertLessThanOrEqual(navigationBar.frame.minY - selector.frame.maxY, 20)
        XCTAssertEqual(
            dock.frame.minY - navigationBar.frame.maxY,
            72,
            accuracy: 2,
            "The actual compact workspace must leave the documented destination viewport below navigation."
        )
        XCTAssertTrue(selector.isHittable)
        XCTAssertTrue(destinationControl.isHittable)
        XCTAssertTrue(dock.isHittable)
        XCTAssertEqual(app.sheets.count, 0)
        attachScreenshot(named: "ipad-studio-compact-advanced-dock")
    }

    func test_iPadStudioPortraitShowsDockForEveryKeyboardHeight() {
        XCUIDevice.shared.orientation = .portrait
        var heights: [CGFloat] = []
        for preset in ["small", "regular", "tall", "kiosk"] {
            let app = launchNumPad(debugRoutes: ["entitle?pro=1", "preset?value=\(preset)"])
            let dock = app.otherElements["studio.keyboard-dock"]
            XCTAssertTrue(dock.waitForExistence(timeout: 20), "Dock missing for \(preset)")
            assertDockPinned(dock, in: app)
            heights.append(dock.frame.height)
            attachScreenshot(named: "ipad-studio-portrait-\(preset)")
            app.terminate()
        }
        XCTAssertLessThan(heights[0], heights[1])
        XCTAssertLessThan(heights[1], heights[2])
        XCTAssertLessThan(heights[2], heights[3])
    }

    func test_iPadFirstInstallProgressesThroughWowEnableHeightThenTryIt() {
        let app = launchNumPad(
            skipOnboarding: false,
            resetAppGroup: false,
            additionalLaunchArguments: [
                "-debugResetOnboardingFresh",
                "-debugOnboardingEnableAfterSettings"
            ]
        )

        XCTAssertTrue(app.staticTexts["Math, right where you type."].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["How tall should your NumPad be?"].exists)
        XCTAssertFalse(app.textFields["onboarding.tryIt.textField"].exists)

        app.buttons["onboarding.wow.continue"].tap()

        let enableAction = app.buttons["onboarding.enable.openSettings"]
        XCTAssertTrue(enableAction.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["How tall should your NumPad be?"].exists)
        XCTAssertFalse(app.textFields["onboarding.tryIt.textField"].exists)

        enableAction.tap()
        app.activate()

        XCTAssertTrue(app.staticTexts["How tall should your NumPad be?"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["onboarding.height.small"].exists)
        XCTAssertTrue(app.buttons["onboarding.height.regular"].exists)
        XCTAssertTrue(app.buttons["onboarding.height.tall"].exists)
        XCTAssertTrue(app.buttons["onboarding.height.kiosk"].exists)
        XCTAssertFalse(app.textFields["onboarding.tryIt.textField"].exists)

        app.buttons["onboarding.height.regular"].tap()

        XCTAssertTrue(app.textFields["onboarding.tryIt.textField"].waitForExistence(timeout: 5))
        app.buttons["onboarding.tryIt.done"].tap()
        let dock = app.otherElements["studio.keyboard-dock"]
        // The preserved first-run value sheet may be pushed immediately after onboarding. Close it
        // when it appears so this flow verifies the user returns to the permanent Studio workspace.
        if !dock.waitForExistence(timeout: 2) {
            let firstRunUpsell = app.descendants(matching: .any)["store.first-run-upsell"]
            XCTAssertTrue(
                firstRunUpsell.waitForExistence(timeout: 5),
                "Only the source-specific first-run value sheet may interrupt this transition"
            )
            let store = app.navigationBars["NumPad Pro"]
            XCTAssertTrue(store.waitForExistence(timeout: 5))
            store.buttons["Back"].tap()
            XCTAssertTrue(app.otherElements["studio.ipad-workspace"].waitForExistence(timeout: 5))
        }
        XCTAssertTrue(dock.waitForExistence(timeout: 10))
        XCTAssertFalse(app.textFields["onboarding.tryIt.textField"].exists)
    }

    func test_iPadLaunchWithOnboardingAlreadyShownNeverShowsHeight() {
        let firstLaunch = launchNumPad(
            skipOnboarding: false,
            resetAppGroup: false,
            additionalLaunchArguments: [
                "-debugResetOnboardingFresh",
                "-debugOnboardingEnableAfterSettings"
            ]
        )
        XCTAssertTrue(firstLaunch.staticTexts["Math, right where you type."].waitForExistence(timeout: 10))
        firstLaunch.terminate()

        let app = launchNumPad(
            skipOnboarding: false,
            resetAppGroup: false,
            additionalLaunchArguments: [
                "-debugResetOnboardingPreservingShown",
                "-debugOnboardingEnableAfterSettings"
            ]
        )

        let instructions = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH 'Almost done!'")
        ).firstMatch
        XCTAssertTrue(instructions.waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["Math, right where you type."].exists)
        XCTAssertFalse(app.staticTexts["How tall should your NumPad be?"].exists)
        XCTAssertFalse(app.textFields["onboarding.tryIt.textField"].exists)
    }

    func test_iPadHeightChoiceKeepsKioskReachableAtAccessibilityTextSize() {
        let app = launchNumPad(
            skipOnboarding: false,
            additionalLaunchArguments: [
                "-debugOnboardingHeight", "1",
                "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
            ]
        )
        let kiosk = app.buttons["onboarding.height.kiosk"]
        XCTAssertTrue(kiosk.waitForExistence(timeout: 10))
        for _ in 0..<5 where !kiosk.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(kiosk.isHittable)
    }

    private func assertDockPinned(_ dock: XCUIElement, in app: XCUIApplication) {
        XCTAssertGreaterThan(dock.frame.height, 100)
        XCTAssertGreaterThanOrEqual(dock.frame.maxY, app.frame.maxY - 60)
        XCTAssertLessThanOrEqual(dock.frame.maxY, app.frame.maxY + 1)
    }

    private func selectDestination(_ title: String, in app: XCUIApplication) {
        let compact = app.segmentedControls["studio.ipad.destinations"]
        if compact.exists {
            let segment = compact.buttons[title]
            XCTAssertTrue(segment.waitForExistence(timeout: 5))
            segment.tap()
            return
        }
        let button = app.buttons["studio.ipad.\(title.lowercased())"]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.tap()
    }
}
