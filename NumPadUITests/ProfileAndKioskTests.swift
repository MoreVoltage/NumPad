//
//  ProfileAndKioskTests.swift
//  NumPadUITests
//

import XCTest

final class ProfileAndKioskTests: XCTestCase {
    func test_iPadKioskReadinessUsesHumanReadableStatusAndPolicy() {
        let app = launchNumPad()
        let kiosk = app.tables.cells.matching(identifier: "sidebar.kioskProvisioning").firstMatch
        XCTAssertTrue(kiosk.waitForExistence(timeout: 10), "iPad sidebar must expose Kiosk Provisioning")
        kiosk.tap()

        XCTAssertTrue(app.navigationBars["Kiosk Provisioning"].waitForExistence(timeout: 5))
        let readiness = app.tables.cells.matching(identifier: "kiosk.readiness").firstMatch
        XCTAssertTrue(readiness.waitForExistence(timeout: 5))
        let readinessLabel = readiness.staticTexts.allElementsBoundByIndex
            .map(\.label)
            .joined(separator: " — ")
        XCTAssertTrue(
            readinessLabel.contains("Blocked")
                || readinessLabel.contains("Needs Attention")
                || readinessLabel.contains("Ready"),
            "Readiness must use localized human-facing status text, not a raw enum: \(readinessLabel)"
        )
        XCTAssertFalse(readinessLabel.contains("blocked —"))
        XCTAssertFalse(readinessLabel.contains("warning —"))
        XCTAssertFalse(readinessLabel.contains("ready —"))

        let policy = app.tables.cells.matching(identifier: "kiosk.policy").firstMatch
        if !policy.waitForExistence(timeout: 2) {
            app.swipeUp()
        }
        XCTAssertTrue(policy.waitForExistence(timeout: 5), "Kiosk policy must be presented in plain language")
        let policyLabel = policy.staticTexts.allElementsBoundByIndex
            .map(\.label)
            .joined(separator: " — ")
        XCTAssertTrue(policyLabel.contains("Session Policy"))
    }

    func test_profilesBuiltInsVisibleActivateAndDuplicate() throws {
        let app = launchNumPad()
        let profiles = app.tables.cells.matching(identifier: "sidebar.profiles").firstMatch
        let homeProfiles = app.tables.staticTexts["Profiles"]
        if profiles.waitForExistence(timeout: 3) {
            profiles.tap()
        } else {
            XCTAssertTrue(homeProfiles.waitForExistence(timeout: 20), "Profiles row should appear")
            // Disambiguate when multiple "Profiles" labels exist (iPad sidebar + detail).
            let matches = app.tables.staticTexts.matching(NSPredicate(format: "label == %@", "Profiles"))
            XCTAssertGreaterThan(matches.count, 0)
            matches.element(boundBy: 0).tap()
        }

        let builtInHeader = app.tables.staticTexts["Built-in Templates"]
        XCTAssertTrue(builtInHeader.waitForExistence(timeout: 5))

        let finance = app.tables.cells.matching(identifier: "profile.builtin.finance").firstMatch
        if finance.waitForExistence(timeout: 3) {
            finance.tap()
        } else {
            let financeLabel = app.tables.cells.staticTexts["Finance"]
            XCTAssertTrue(financeLabel.waitForExistence(timeout: 5))
            financeLabel.tap()
        }

        // iPad requires a popover/action sheet with an anchor — wait for Activate.
        let activate = app.buttons["Activate"]
        XCTAssertTrue(activate.waitForExistence(timeout: 5), "Activate action must appear (popover-safe)")
        // Prefer Duplicate for this test so we reach the editor without changing live settings mid-suite.
        let duplicate = app.buttons["Duplicate"]
        XCTAssertTrue(duplicate.waitForExistence(timeout: 2))
        duplicate.tap()

        XCTAssertTrue(app.navigationBars["Edit Profile"].waitForExistence(timeout: 5))
        app.navigationBars.buttons["Cancel"].tap()
    }
}
