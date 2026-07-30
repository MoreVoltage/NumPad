//
//  ProfileAndKioskTests.swift
//  NumPadUITests
//

import XCTest

final class ProfileAndKioskTests: XCTestCase {
    func test_iPadKioskReadinessUsesHumanReadableStatusAndPolicy() throws {
        guard XCUIScreen.main.screenshot().image.size.width >= 700 else {
            throw XCTSkip("Kiosk readiness sidebar coverage is iPad-only")
        }
        let app = launchNumPad()
        let kiosk = app.tables.cells.matching(identifier: "sidebar.kioskProvisioning").firstMatch
        XCTAssertTrue(kiosk.waitForExistence(timeout: 10), "iPad sidebar must expose Kiosk mode")
        kiosk.tap()

        XCTAssertTrue(app.navigationBars["Kiosk mode"].waitForExistence(timeout: 5))
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

    func test_iPadSavedSetupsRoutesToStudioDetail() throws {
        guard XCUIScreen.main.screenshot().image.size.width >= 700 else {
            throw XCTSkip("Saved setups sidebar coverage is iPad-only")
        }
        let app = launchNumPad()
        let profiles = app.tables.cells.matching(identifier: "sidebar.profiles").firstMatch
        XCTAssertTrue(profiles.waitForExistence(timeout: 10), "iPad sidebar must expose Saved setups")
        profiles.tap()
        XCTAssertTrue(app.navigationBars["Saved setups"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.otherElements["studio.saved-setups"].waitForExistence(timeout: 5))

        let finance = app.staticTexts["Finance"].firstMatch
        XCTAssertTrue(finance.waitForExistence(timeout: 5))
        finance.tap()
        XCTAssertTrue(app.otherElements["studio.saved-setup.detail"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["studio.saved-setup.apply"].exists)
        XCTAssertTrue(app.buttons["studio.saved-setup.copy"].exists)
    }
}
