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
