//
//  KeyboardStudioUITests.swift
//  NumPadUITests
//

import XCTest

final class KeyboardStudioUITests: XCTestCase {
    func test_readinessHeroStatesWhetherKeyboardIsReadyOrNeedsAttention() {
        let app = launchNumPad()

        let status = studioElement(in: app, identifier: "studio.keyboard.status")
        XCTAssertTrue(status.waitForExistence(timeout: 10))
        XCTAssertTrue(status.label.contains("Ready") || status.label.contains("Needs attention"))
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

    func test_chooseKeysShowsFreeAndLockedChoices() {
        let app = launchNumPad(debugRoutes: ["entitle?pro=0"])

        let chooseKeys = studioElement(in: app, identifier: "studio.keyboard.choose-keys")
        XCTAssertTrue(chooseKeys.exists)
        chooseKeys.tap()
        XCTAssertTrue(studioElement(in: app, identifier: "studio.keyset.numbers").waitForExistence(timeout: 5))
        XCTAssertTrue(studioElement(in: app, identifier: "studio.keyset.prices").exists)
    }

    func test_lettersQuickChangeIsHiddenWhenTheLettersGateIsUnavailableAtLargeTextSize() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-skipOnboarding", "-resetUITestAppGroup",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXL",
            "-debugRoute", "entitle?pro=0"
        ]
        app.launch()

        XCTAssertFalse(studioElement(in: app, identifier: "studio.keyboard.letters").exists)
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
}
