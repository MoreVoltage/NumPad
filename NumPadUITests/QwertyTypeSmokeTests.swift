//
//  QwertyTypeSmokeTests.swift
//  NumPadUITests
//
//  E2E smoke for NumPad Type, the full-QWERTY extension (docs/plans/full-keyboard/): enables
//  the keyboard via Settings.app (the only mechanism that works on this runtime — see
//  UITestSupport.swift), raises it on the debug typing surface with simulated Pro entitlement,
//  and drives real typing through the extension process: autocap + autocorrect ("teh " → "The "),
//  the numpad flip, and the pack switch. This is the seed of the §7.2 E2E typing matrix, not its
//  entirety — the full matrix (period/comma both states, wizard flows, iPad) tracks in the plan.
//

import XCTest

final class QwertyTypeSmokeTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// NumPad Type is frontmost when its two unique utility keys (numpad flip + pack switch,
    /// both with explicit accessibility labels) are present. Letter keys can't anchor this
    /// check (autocap relabels them "Q"/"q"), and neither can the number row — LAST-USED
    /// strip persistence means a pack row may be showing instead (owner decision §0.4).
    private func isQwertyTypeActive(_ app: XCUIApplication) -> Bool {
        app.buttons["Switch pack"].firstMatch.exists && app.buttons["NumPad"].firstMatch.exists
    }

    /// Cycles the pack switch until the number row is showing — normalizes away whatever
    /// LAST-USED pack an earlier run persisted to the app group. Coordinate taps: the
    /// pack-switch key's frame is stable (trailing strip slot) even while the strip's other
    /// buttons are being swapped, and a plain `.tap()` on a mid-rebuild element was observed
    /// to synthesize an off-element touch that dismissed the host sheet entirely.
    private func normalizeStripToNumbers(_ app: XCUIApplication) {
        var hops = 0
        while !app.buttons["7"].firstMatch.exists && hops < 8 {
            guard isQwertyTypeActive(app) else { return }
            let packSwitch = app.buttons["Switch pack"].firstMatch
            guard packSwitch.waitForExistence(timeout: 3) else { return }
            packSwitch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            hops += 1
            Thread.sleep(forTimeInterval: 0.5)
        }
    }

    /// Switches the active keyboard to NumPad Type. Tap-cycling the globe is not reliable
    /// with three keyboards installed (observed on iPad: NumPad Type never activated across
    /// six taps), so the primary path is the globe's long-press keyboard picker — selecting
    /// the keyboard by name — with tap-cycling kept as the fallback. The picker menu can be
    /// hosted by the app process or by SpringBoard depending on runtime, so both are checked.
    @discardableResult
    private func switchToQwertyType(_ app: XCUIApplication) -> Bool {
        if isQwertyTypeActive(app) { return true }
        let tutorialContinue = app.buttons["Continue"]
        if tutorialContinue.waitForExistence(timeout: 2) {
            tutorialContinue.tap()
        }
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for _ in 0..<4 {
            // firstMatch: once NumPad Type has been frontmost, BOTH its own globe key and the
            // system accessory globe carry the "Next keyboard" label.
            let globe = app.buttons["Next keyboard"].firstMatch
            guard globe.waitForExistence(timeout: 4) else { break }
            globe.press(forDuration: 1.2)
            let menuItem = [app.staticTexts["NumPad Type"].firstMatch,
                            springboard.staticTexts["NumPad Type"].firstMatch]
                .first { $0.waitForExistence(timeout: 2) }
            if let menuItem = menuItem {
                menuItem.tap()
            } else {
                // No picker appeared — treat the press as a plain tap-cycle step.
                globe.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            }
            Thread.sleep(forTimeInterval: 1.5)
            if isQwertyTypeActive(app) { return true }
        }
        return isQwertyTypeActive(app)
    }

    /// Settings.app enablement for the "NumPad Type" keyboard specifically, via the per-app
    /// path (Settings → Apps → NumPad → Keyboards) — identical on iPhone and iPad. The
    /// General → Keyboard → Add New Keyboard sheet is a dead end on iPadOS: it buries the
    /// third-party section below every language keyboard and its search field doesn't index
    /// third-party apps at all (both confirmed via tree dumps — see git history).
    @discardableResult
    private func ensureQwertyTypeEnabled() -> Bool {
        // On a fresh simulator the app-under-test is only installed by its first launch —
        // and Settings can't list an app (or register its keyboard extensions) that isn't
        // installed yet. Launch-and-quit once so the per-app page exists.
        let numpad = XCUIApplication()
        numpad.launch()
        numpad.terminate()

        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        settings.launch()
        defer { settings.terminate() }

        guard tapRow(in: settings, labeled: "Apps") else {
            XCTFail("ensureQwertyTypeEnabled: Apps row not found in Settings")
            return false
        }
        // The apps list virtualizes its rows — "NumPad" is not even in the accessibility
        // tree until scrolled into view, so scroll-and-check rather than wait-and-scroll
        // (tapRow's shape) for this one.
        let appRow = settings.staticTexts["NumPad"].firstMatch
        var swipes = 0
        while !appRow.exists && swipes < 10 {
            settings.swipeUp()
            swipes += 1
        }
        guard appRow.exists else {
            attachScreenshot(named: "enable-FAILED-no-app-row")
            XCTFail("ensureQwertyTypeEnabled: NumPad app page not found under Apps (is the app installed?)")
            return false
        }
        appRow.tap()
        guard tapRow(in: settings, labeled: "Keyboards") else {
            XCTFail("ensureQwertyTypeEnabled: Keyboards row not found on NumPad's app page")
            return false
        }

        // One Switch per keyboard extension, identifier = the extension's bundle ID.
        let typeSwitch = settings.switches["com.morevoltage.NumPad.KeyboardType"].firstMatch
        guard typeSwitch.waitForExistence(timeout: 5) else {
            attachScreenshot(named: "enable-FAILED-no-type-switch")
            XCTFail("ensureQwertyTypeEnabled: NumPad Type switch not found on the app's Keyboards page")
            return false
        }
        if (typeSwitch.value as? String) != "1" {
            // Tap the switch control itself — tapping the row label does not toggle it.
            typeSwitch.switches.firstMatch.tap()
            Thread.sleep(forTimeInterval: 0.5)
        }
        guard (typeSwitch.value as? String) == "1" else {
            attachScreenshot(named: "enable-FAILED-switch-still-off")
            XCTFail("ensureQwertyTypeEnabled: NumPad Type switch did not turn on")
            return false
        }
        return true
    }

    func testQwertyTypingAutocapAutocorrectFlipAndPackSwitch() throws {
        guard ensureQwertyTypeEnabled() else { return }

        // Pro-entitled (the keyboard is Pro-gated, plan §5) on the debug typing surface.
        let app = launchNumPad(debugRoutes: ["entitle?pro=1", "typing"])
        let field = app.textFields.firstMatch
        guard field.waitForExistence(timeout: 20) else {
            return XCTFail("typing surface never appeared")
        }
        if !waitForAnyKeyboard(app, timeout: 6) {
            field.tap()
            guard waitForAnyKeyboard(app, timeout: 10) else {
                return XCTFail("no keyboard ever appeared on the typing surface")
            }
        }
        guard switchToQwertyType(app) else {
            attachScreenshot(named: "qwerty-switch-failed")
            return XCTFail("could not switch the active keyboard to NumPad Type")
        }
        // A previous run may have left a pack on the strip (LAST-USED persistence) — start
        // every assertion from the number row.
        normalizeStripToNumbers(app)
        XCTAssertTrue(app.buttons["7"].firstMatch.exists, "top strip shows the number row")
        attachScreenshot(named: "qwerty-letters-layer")

        // Autocap capitalizes the first letter; autocorrect fixes "Teh" → "The" at the space.
        // The first key is labeled "T": autocap has shift engaged at the sentence start, and
        // typing it auto-unshifts back to lowercase labels for the rest.
        XCTAssertTrue(app.buttons["T"].waitForExistence(timeout: 3),
                      "letters render uppercase while autocap shift is engaged")
        app.buttons["T"].tap()
        XCTAssertTrue(app.buttons["e"].waitForExistence(timeout: 3),
                      "keys relabel lowercase once the one-shot shift is consumed")
        app.buttons["e"].tap()
        app.buttons["h"].tap()
        attachScreenshot(named: "qwerty-mid-word-suggestions")
        app.buttons["space"].tap()
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssertEqual(field.value as? String, "The ",
                       "autocap ('t'→'T' at sentence start) + boundary autocorrect (Teh→The)")

        // One-tap numpad flip: digits grid replaces the letter rows, letters come back on
        // the second tap.
        app.buttons["NumPad"].firstMatch.tap()
        // Digits exist on BOTH the top strip and the flipped canvas — queries must firstMatch.
        XCTAssertTrue(app.buttons["4"].firstMatch.waitForExistence(timeout: 3),
                      "numpad flip shows the digit grid")
        XCTAssertFalse(app.buttons["q"].exists, "letter rows are gone while flipped")
        attachScreenshot(named: "qwerty-numpad-flip")
        app.buttons["4"].firstMatch.tap()
        app.buttons["2"].firstMatch.tap()
        app.buttons["NumPad"].firstMatch.tap()
        XCTAssertTrue(app.buttons["q"].waitForExistence(timeout: 3), "flip returns to QWERTY")
        XCTAssertEqual(field.value as? String, "The 42", "digits typed on the flipped canvas landed")

        // Pack switch: from the number row, the first tap swaps in the Grammar pack (em dash
        // ships first in the family). Coordinate tap — see normalizeStripToNumbers.
        app.buttons["Switch pack"].firstMatch
            .coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.buttons["\u{2014}"].waitForExistence(timeout: 3),
                      "Grammar ships first in the QWERTY pack family (owner decision §0.3)")
        attachScreenshot(named: "qwerty-grammar-pack")
        app.buttons["\u{2014}"].firstMatch.tap()
        Thread.sleep(forTimeInterval: 0.3)
        XCTAssertEqual(field.value as? String, "The 42\u{2014}", "grammar key inserts its glyph")

        // And back to the number row after cycling through the whole family.
        normalizeStripToNumbers(app)
        XCTAssertTrue(app.buttons["7"].firstMatch.exists, "pack switch cycles back to the number row")
        attachScreenshot(named: "qwerty-number-row-restored")
    }
}
