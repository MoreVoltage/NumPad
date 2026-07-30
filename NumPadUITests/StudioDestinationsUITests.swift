//
//  StudioDestinationsUITests.swift
//  NumPadUITests
//

import XCTest

final class StudioDestinationsUITests: XCTestCase {
    func test_featuresHelpAndAdvancedExposeWorkingStudioDestinations() {
        let app = launchNumPad(debugRoutes: ["entitle?pro=0"])

        app.tabBars.buttons["Features"].tap()
        XCTAssertTrue(element(app, "studio.features.calculator").waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, "studio.features.reusable-text").exists)
        let custom = element(app, "studio.features.custom-keys")
        XCTAssertTrue(custom.exists)
        XCTAssertEqual(custom.value as? String, "Pro")
        custom.tap()
        XCTAssertTrue(app.navigationBars["NumPad Pro"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()

        app.tabBars.buttons["Help"].tap()
        XCTAssertTrue(element(app, "studio.help.status").waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, "studio.help.privacy").exists)
        XCTAssertTrue(element(app, "studio.help.restore").exists)
        XCTAssertTrue(element(app, "studio.help.version").exists)

        app.tabBars.buttons["Keyboard"].tap()
        let advanced = app.buttons["studio.keyboard.advanced"]
        XCTAssertTrue(advanced.waitForExistence(timeout: 5))
        advanced.tap()
        XCTAssertTrue(element(app, "studio.advanced.saved-setups").waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, "studio.advanced.kiosk").exists)
        XCTAssertTrue(element(app, "studio.advanced.move-setups").exists)
        XCTAssertFalse(element(app, "studio.advanced.managed-settings").exists)
        element(app, "studio.advanced.kiosk").tap()
        XCTAssertTrue(app.navigationBars["NumPad Pro"].waitForExistence(timeout: 5), "An unentitled Kiosk-mode entry must present the Store before any setup state can change.")
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "identifier == %@", identifier)).firstMatch
    }
}
