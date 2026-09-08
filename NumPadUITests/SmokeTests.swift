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
    func testKeyboardStaysUsableWithoutWhatsNewAfterRelaunch() throws {
        continueAfterFailure = false
        // Install/launch first so a fresh simulator can offer the extension in Settings.
        let initial = launchNumPad()
        initial.terminate()
        for attempt in 0..<2 {
            guard let result = launchNumPadOnTypingSurface() else {
                return XCTFail("Could not reach the typing surface")
            }
            XCTAssertTrue(result.numPadActive, "NumPad must actually be the active keyboard")
            let promotion = result.app.buttons.matching(
                NSPredicate(format: "label BEGINSWITH %@", "What's New")).firstMatch
            XCTAssertFalse(promotion.exists, "Update promotions must not occupy the keyboard")
            result.app.buttons["1"].firstMatch.tap()
            result.app.buttons["2"].firstMatch.tap()
            XCTAssertEqual(result.field.value as? String, "12")
            attachScreenshot(named: "keyboard-without-promotion-\(attempt)")
            result.app.terminate()
        }
    }
}
