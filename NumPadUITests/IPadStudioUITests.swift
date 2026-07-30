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
        XCTAssertTrue(dock.exists)
        attachScreenshot(named: "ipad-studio-landscape-advanced")
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
