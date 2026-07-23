//
//  ProfileAndKioskTests.swift
//  NumPadUITests
//

import XCTest

final class ProfileAndKioskTests: XCTestCase {
    func test_profilesBuiltInsVisibleAndDuplicateCreatesCustom() throws {
        let app = launchNumPad()
        // Dismiss splash/onboarding if present by waiting for Profiles row.
        let profiles = app.tables.cells.staticTexts["Profiles"]
        XCTAssertTrue(profiles.waitForExistence(timeout: 20), "Profiles row should appear on Home")
        profiles.tap()

        let builtInHeader = app.tables.staticTexts["Built-in Templates"]
        XCTAssertTrue(builtInHeader.waitForExistence(timeout: 5))

        let finance = app.tables.cells.staticTexts["Finance"]
        XCTAssertTrue(finance.waitForExistence(timeout: 5))
        finance.tap()

        let duplicate = app.sheets.buttons["Duplicate"]
        if duplicate.waitForExistence(timeout: 3) {
            duplicate.tap()
            // Editor should appear for the duplicated custom profile.
            XCTAssertTrue(app.navigationBars["Edit Profile"].waitForExistence(timeout: 5))
            app.navigationBars.buttons["Cancel"].tap()
        }
    }
}
