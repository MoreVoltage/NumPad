//
//  SmokeTests.swift
//  NumPadUITests
//
//  A minimal trial test used to verify the NumPadUITests target itself — build settings, scheme
//  wiring, and app installation on the simulator — before the full test matrix is written. Kept
//  around afterwards as a cheap sanity check for the harness.
//

import XCTest

final class SmokeTests: XCTestCase {
    func testAppLaunches() throws {
        let app = launchNumPad()
        XCTAssertEqual(app.state, .runningForeground)
        attachScreenshot(named: "00-smoke-launch")
    }
}

final class KeyboardReleaseRegressionTests: XCTestCase {
    func testWhatsNewCanBeDismissedAndStaysGoneAfterRelaunch() throws {
        continueAfterFailure = false
        // Install/launch first so a fresh simulator can offer the extension in Settings.
        let initial = launchNumPad()
        initial.terminate()
        for attempt in 0..<2 {
            guard let result = launchNumPadOnTypingSurface() else {
                return XCTFail("Could not reach the typing surface")
            }
            XCTAssertTrue(result.numPadActive, "NumPad must actually be the active keyboard")
            let promotion = result.app.buttons["whatsnew.banner.open"]
            let dismiss = result.app.buttons["whatsnew.banner.dismiss"]
            if attempt == 0 {
                XCTAssertTrue(promotion.waitForExistence(timeout: 5), "An unseen update offers a route into the app")
                XCTAssertTrue(dismiss.isHittable, "The close button must be independently tappable")
                attachScreenshot(named: "keyboard-update-banner-with-dismiss")
                dismiss.tap()
            }
            XCTAssertFalse(promotion.exists, "Dismissal must survive keyboard relaunch")
            XCTAssertFalse(dismiss.exists)
            XCTAssertEqual(result.app.state, .runningForeground, "Dismissal must not navigate away")
            XCTAssertFalse(result.app.buttons["whatsnew.allow"].exists, "Dismissal must not open permission UI")
            result.app.buttons["1"].firstMatch.tap()
            result.app.buttons["2"].firstMatch.tap()
            XCTAssertEqual(result.field.value as? String, "12")
            attachScreenshot(named: "keyboard-after-banner-dismissal-\(attempt)")
            result.app.terminate()
        }
    }
}
