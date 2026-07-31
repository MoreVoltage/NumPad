//
//  KeyboardStudioUITests.swift
//  NumPadUITests
//

import XCTest

final class KeyboardStudioUITests: XCTestCase {
    func test_readyReadinessHeroHasNoRepairAction() {
        let app = launchNumPad(additionalLaunchArguments: ["-debugStudioKeyboardReady", "1"])

        let status = studioElement(in: app, identifier: "studio.keyboard.status")
        XCTAssertTrue(status.waitForExistence(timeout: 10))
        XCTAssertTrue(status.label.contains("Ready"))
        XCTAssertFalse(studioElement(in: app, identifier: "studio.keyboard.openSetup").exists)
    }

    func test_needsAttentionReadinessHeroShowsRepairAction() {
        let app = launchNumPad(additionalLaunchArguments: ["-debugStudioKeyboardReady", "0"])

        let status = studioElement(in: app, identifier: "studio.keyboard.status")
        let repairAction = studioElement(in: app, identifier: "studio.keyboard.openSetup")
        XCTAssertTrue(status.waitForExistence(timeout: 10))
        XCTAssertTrue(status.label.contains("Needs attention"))
        XCTAssertTrue(repairAction.exists)
        XCTAssertTrue(repairAction.isHittable)
    }

    func test_quickChangeRoundTripOpensAppearanceStudio() {
        let app = launchNumPad()

        let appearance = studioElement(in: app, identifier: "studio.keyboard.appearance")
        XCTAssertTrue(appearance.exists)
        appearance.tap()
        XCTAssertTrue(app.navigationBars["Appearance"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(appearance.waitForExistence(timeout: 5))
    }

    func test_quickChangeRoundTripRefreshesTheExistingRootPreview() {
        let app = launchNumPad()

        let chooseKeys = studioElement(in: app, identifier: "studio.keyboard.choose-keys")
        XCTAssertTrue(scrollFullyIntoView(chooseKeys, in: app))
        chooseKeys.tap()

        let calculations = studioElement(in: app, identifier: "studio.keyset.calculations")
        XCTAssertTrue(calculations.waitForExistence(timeout: 5))
        calculations.tap()
        app.navigationBars.buttons.firstMatch.tap()

        let preview = studioElement(in: app, identifier: "studio.keyboard.preview")
        XCTAssertTrue(preview.waitForExistence(timeout: 5))
        XCTAssertTrue(preview.label.contains("Math"), "Returning to the existing root must show the chosen key set in its live preview.")
    }

    func test_chooseKeysShowsFreeAndLockedAffordancesAndLockedTapPreservesSelection() {
        let app = launchNumPad(debugRoutes: ["entitle?pro=0"])

        let chooseKeys = studioElement(in: app, identifier: "studio.keyboard.choose-keys")
        XCTAssertTrue(chooseKeys.exists)
        XCTAssertTrue(scrollFullyIntoView(chooseKeys, in: app))
        chooseKeys.tap()
        let numbers = studioElement(in: app, identifier: "studio.keyset.numbers")
        let prices = studioElement(in: app, identifier: "studio.keyset.prices")
        XCTAssertTrue(numbers.waitForExistence(timeout: 5))
        XCTAssertTrue(numbers.isHittable)
        XCTAssertTrue((numbers.value as? String ?? "").isEmpty, "Numbers is the free choice and should not have a Pro lock value.")
        XCTAssertTrue(numbers.isSelected, "A fresh debug state should show the free Numbers choice selected.")
        XCTAssertTrue(prices.exists)
        XCTAssertEqual(prices.value as? String, "Pro")
        XCTAssertFalse(prices.isSelected)

        prices.tap()
        XCTAssertTrue(app.navigationBars["NumPad Pro"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()

        XCTAssertTrue(numbers.waitForExistence(timeout: 5))
        XCTAssertTrue(numbers.isSelected, "A locked key set must not change the selected setting before purchase.")
        XCTAssertEqual(prices.value as? String, "Pro")
    }

    func test_keySetCoreControlsRemainHittableAtAccessibilityTextSize() {
        let app = launchNumPad(
            debugRoutes: ["entitle?pro=0"],
            additionalLaunchArguments: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXL"]
        )

        let chooseKeys = studioElement(in: app, identifier: "studio.keyboard.choose-keys")
        XCTAssertTrue(chooseKeys.waitForExistence(timeout: 10))
        XCTAssertTrue(scrollFullyIntoView(chooseKeys, in: app))
        XCTAssertTrue(chooseKeys.isHittable)
        chooseKeys.tap()

        let numbers = studioElement(in: app, identifier: "studio.keyset.numbers")
        XCTAssertTrue(numbers.waitForExistence(timeout: 5), "The primary key-set control must remain present at accessibility text size.")
        XCTAssertTrue(scrollFullyIntoView(numbers, in: app), "The primary key-set control must scroll fully into view at accessibility text size.")
        XCTAssertTrue(numbers.isHittable, "The primary key-set control must remain reachable at accessibility text size.")
        XCTAssertGreaterThanOrEqual(numbers.frame.height, 44, "The primary key-set control must retain a full touch target.")
        XCTAssertGreaterThan(numbers.frame.width, 0, "The primary key-set control must not be clipped away.")
        XCTAssertLessThanOrEqual(numbers.frame.maxY, app.windows.firstMatch.frame.maxY, "The primary key-set control must be fully within the visible viewport.")

        XCTAssertFalse(studioElement(in: app, identifier: "studio.keyboard.letters").exists)
    }

    func test_iPhoneOmitsIPadLayoutControlsAndKeepsPhoneControls() {
        let app = launchNumPad(debugRoutes: ["entitle?pro=1"])
        let sizeAndFeel = studioElement(in: app, identifier: "studio.keyboard.size-feel")
        XCTAssertTrue(scrollFullyIntoView(sizeAndFeel, in: app))
        sizeAndFeel.tap()

        XCTAssertTrue(studioElement(in: app, identifier: "studio.size-feel.height.regular").waitForExistence(timeout: 5))
        for size in ["compact", "comfortable", "medium", "wide", "full"] {
            XCTAssertFalse(studioElement(in: app, identifier: "studio.size-feel.width.\(size)").exists)
        }

        app.navigationBars.buttons.firstMatch.tap()
        let letters = studioElement(in: app, identifier: "studio.keyboard.letters")
        XCTAssertTrue(letters.waitForExistence(timeout: 5))
        letters.tap()

        XCTAssertTrue(studioElement(in: app, identifier: "studio.letters.autocorrect").waitForExistence(timeout: 5))
        XCTAssertFalse(studioElement(in: app, identifier: "studio.letters.layout.standard").exists)
        XCTAssertFalse(studioElement(in: app, identifier: "studio.letters.layout.full").exists)
        XCTAssertFalse(app.segmentedControls["studio.letters.full-keyboard-side"].exists)
    }

    private func studioElement(in app: XCUIApplication, identifier: String) -> XCUIElement {
        let element = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier == %@", identifier)
        ).firstMatch
        for _ in 0..<5 where !element.exists {
            app.swipeUp()
        }
        return element
    }

    private func scrollFullyIntoView(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        let window = app.windows.firstMatch
        for _ in 0..<5 {
            let frame = element.frame
            if element.isHittable,
               frame.minY >= window.frame.minY,
               frame.maxY <= window.frame.maxY {
                return true
            }
            app.swipeUp()
        }
        let frame = element.frame
        return element.isHittable && frame.minY >= window.frame.minY && frame.maxY <= window.frame.maxY
    }
}
