//
//  QwertyTypeSmokeTests.swift
//  NumPadUITests
//
//  E2E smoke for NumPad Type, the full-QWERTY PAGE inside the single NumPad keyboard
//  (docs/plans/full-keyboard/ — owner decision 2026-07-09 folded the separate KeyboardType
//  extension into the numpad extension: one keyboard in iOS Settings, one Full Access grant,
//  two pages). Enables the NumPad keyboard via Settings.app, raises it on the debug typing
//  surface with simulated Pro entitlement + the full-keyboard rollout flag, and drives real
//  typing through the extension process: autocap + autocorrect ("teh " → "The "), the
//  ABC ⇄ NumPad page switch (the numpad page is the real numpad, identical to production),
//  and the pack switch. This is the seed of the §7.2 E2E typing matrix, not its entirety.
//

import XCTest

final class QwertyTypeSmokeTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// The QWERTY page is frontmost when its two unique utility keys (numpad page-switch +
    /// pack switch, both with explicit accessibility labels) are present. Letter keys can't
    /// anchor this check (autocap relabels them "Q"/"q"), and neither can the number row —
    /// LAST-USED strip persistence means a pack row may be showing instead (owner decision §0.4).
    private func isQwertyPageActive(_ app: XCUIApplication) -> Bool {
        app.buttons["Switch pack"].firstMatch.exists && app.buttons["NumPad"].firstMatch.exists
    }

    /// The NumPad keyboard (either page) is frontmost — both pages carry a pack-switch key
    /// with the "Switch pack" accessibility label; no system keyboard has one. Distinct from
    /// UITestSupport's `isNumPadKeyboardActive`, which the numpad suites use and which is
    /// deliberately numpad-PAGE-only ("Delete"+"Enter") — this test runs with the QWERTY page
    /// gate on, so the keyboard may legitimately raise showing either page.
    private func isNumPadKeyboardRaised(_ app: XCUIApplication) -> Bool {
        app.buttons["Switch pack"].firstMatch.exists
    }

    /// Cycles the pack switch until the Grammar pack (its em dash key) is showing — normalizes
    /// away whatever LAST-USED pack an earlier run persisted to the app group. Entered via ABC,
    /// the strip runs in numpad context (owner note 2026-07-10): the plain number line never
    /// cycles in, which this asserts on every hop. Coordinate taps: the pack-switch key's frame
    /// is stable (trailing strip slot) even while the strip's other buttons are being swapped,
    /// and a plain `.tap()` on a mid-rebuild element was observed to synthesize an off-element
    /// touch that dismissed the host sheet entirely.
    private func normalizeStripToGrammar(_ app: XCUIApplication) {
        var hops = 0
        while !app.buttons["\u{2014}"].firstMatch.exists && hops < 8 {
            guard isQwertyPageActive(app) else { return }
            XCTAssertFalse(app.buttons["7"].firstMatch.exists,
                           "the plain number line must never cycle in while in numpad context")
            let packSwitch = app.buttons["Switch pack"].firstMatch
            guard packSwitch.waitForExistence(timeout: 3) else { return }
            packSwitch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            hops += 1
            Thread.sleep(forTimeInterval: 0.5)
        }
    }

    /// Makes the NumPad keyboard the active keyboard (vs the system keyboard) via the system
    /// accessory globe's long-press picker; tap-cycling is the fallback. Named apart from
    /// UITestSupport's `switchToNumPadKeyboard` (numpad-page-only activity check) for the
    /// same either-page reason as `isNumPadKeyboardRaised`.
    @discardableResult
    private func activateNumPadKeyboard(_ app: XCUIApplication) -> Bool {
        // includeAppButtons must stay false: the QWERTY page's own page-switch key is a
        // button labeled exactly "NumPad", so an app-scoped exact-name query would tap it
        // instead of the picker row whenever the QWERTY page is frontmost.
        switchToKeyboard(app, named: "NumPad", includeAppButtons: false,
                         isActive: { self.isNumPadKeyboardRaised($0) })
    }

    /// Brings the QWERTY page up VIA THE ABC KEY, from whichever page the keyboard reopened
    /// on. If it restored straight onto the QWERTY page (LAST-USED page persistence), hop to
    /// the numpad page first — a fresh-raise QWERTY legitimately shows the number row, while
    /// every strip assertion in this test exercises the via-ABC (numpad-context) semantics,
    /// so the entry path must be deterministic. The numpad page's "ABC" key carries the
    /// "Letters" accessibility label.
    @discardableResult
    private func goToQwertyPage(_ app: XCUIApplication) -> Bool {
        if isQwertyPageActive(app) {
            app.buttons["NumPad"].firstMatch.tap()
            Thread.sleep(forTimeInterval: 0.8)
        }
        let letters = app.buttons["Letters"].firstMatch
        guard letters.waitForExistence(timeout: 4) else { return false }
        letters.tap()
        Thread.sleep(forTimeInterval: 0.8)
        return isQwertyPageActive(app)
    }

    /// Generic keyboard switch via the system accessory globe's long-press picker, selecting
    /// the target keyboard by name. The picker menu can be hosted by the app process or by
    /// SpringBoard depending on runtime, so both are checked.
    @discardableResult
    private func switchToKeyboard(_ app: XCUIApplication, named name: String,
                                  includeAppButtons: Bool,
                                  isActive: (XCUIApplication) -> Bool) -> Bool {
        if isActive(app) { return true }
        let tutorialContinue = app.buttons["Continue"]
        if tutorialContinue.waitForExistence(timeout: 2) {
            tutorialContinue.tap()
        }
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for _ in 0..<4 {
            let globe = app.buttons["Next keyboard"].firstMatch
            guard globe.waitForExistence(timeout: 4) else { break }
            globe.press(forDuration: 1.2)
            // On this runtime the picker is the app-hosted `InputSwitcherTable`, whose rows
            // are Cells labeled "<keyboard> — <app>, <language>" (observed: 'NumPad Type —
            // NumPad, English') — or "<keyboard>, <language>" when the keyboard's display
            // name equals the app's ('NumPad, English'), so an exact-name query can never
            // match them. The em-dash/comma prefixes keep "NumPad" from matching any
            // "NumPad … — …" sibling row. Exact-name static-text/button matchers stay as
            // fallbacks for runtimes that host the picker in SpringBoard with plain labels.
            let pickerRow = NSPredicate(
                format: "label == %@ OR label BEGINSWITH %@ OR label BEGINSWITH %@",
                name, name + " \u{2014}", name + ",")
            var candidates = [app.cells.matching(pickerRow).firstMatch,
                              springboard.cells.matching(pickerRow).firstMatch,
                              springboard.staticTexts[name].firstMatch,
                              springboard.buttons[name].firstMatch]
            if includeAppButtons {
                candidates.append(app.staticTexts[name].firstMatch)
                candidates.append(app.buttons[name].firstMatch)
            }
            let menuItem = candidates.first { $0.waitForExistence(timeout: 2) }
            if let menuItem = menuItem {
                menuItem.tap()
            } else {
                attachScreenshot(named: "picker-after-longpress")
                let appTree = XCTAttachment(string: app.debugDescription)
                appTree.name = "picker-app-tree"
                appTree.lifetime = .keepAlways
                add(appTree)
                let sbTree = XCTAttachment(string: springboard.debugDescription)
                sbTree.name = "picker-springboard-tree"
                sbTree.lifetime = .keepAlways
                add(sbTree)
                // No picker appeared — treat the press as a plain tap-cycle step.
                globe.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            }
            Thread.sleep(forTimeInterval: 1.5)
            // A keyboard raised for the first time may show its own tutorial overlay —
            // dismiss it so the activity check can see the real keys.
            if tutorialContinue.exists { tutorialContinue.tap() }
            if isActive(app) { return true }
        }
        return isActive(app)
    }

    func testQwertyTypingAutocapAutocorrectPageSwitchAndPackSwitch() throws {
        // Single keyboard: enabling the NumPad keyboard is the only Settings step there is.
        guard ensureKeyboardEnabled() else { return }

        // Pro-entitled (the QWERTY page is Pro-gated, plan §5) + the local rollout flag,
        // both written to the app group so the extension's page gate sees them.
        let app = launchNumPad(debugRoutes: ["entitle?pro=1", "fullkeyboard?enabled=1", "typing"])
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
        guard activateNumPadKeyboard(app) else {
            attachScreenshot(named: "keyboard-switch-failed")
            return XCTFail("could not make the NumPad keyboard active")
        }
        guard goToQwertyPage(app) else {
            attachScreenshot(named: "qwerty-page-switch-failed")
            return XCTFail("numpad page offered no working ABC (Letters) key to the QWERTY page")
        }
        // Entered via ABC → numpad-context strip: a virgin selection auto-swaps to Grammar and
        // a previous run's LAST-USED pack may be showing instead — normalize to Grammar either
        // way (the number line never cycles in; asserted per hop inside the helper).
        normalizeStripToGrammar(app)
        XCTAssertTrue(app.buttons["\u{2014}"].firstMatch.exists,
                      "entering via ABC lands the strip on a pack, never the redundant number line")
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

        // Page switch: the "NumPad" key now shows the REAL numpad page — the production
        // keyboard, identical to the standalone build (owner note #2) — not a QWERTY-local
        // digits canvas.
        app.buttons["NumPad"].firstMatch.tap()
        XCTAssertTrue(app.buttons["4"].firstMatch.waitForExistence(timeout: 3),
                      "numpad page shows the real numpad grid")
        XCTAssertTrue(app.buttons["Switch pack"].firstMatch.exists,
                      "the real numpad's pack-switch key is present")
        XCTAssertTrue(app.buttons["Letters"].firstMatch.exists,
                      "the numpad page offers the ABC key back to the QWERTY page")
        XCTAssertFalse(app.buttons["q"].exists, "letter rows are gone on the numpad page")
        // Bottom-row order (owner note 2026-07-10): ABC leftmost, 0 centered under the digit
        // grid, pack switcher immediately right of 0.
        XCTAssertLessThan(app.buttons["Letters"].firstMatch.frame.minX,
                          app.buttons["0"].firstMatch.frame.minX,
                          "ABC sits left of the 0 key")
        XCTAssertLessThan(app.buttons["0"].firstMatch.frame.minX,
                          app.buttons["Switch pack"].firstMatch.frame.minX,
                          "the pack switcher sits right of the 0 key")
        // Owner note 2026-07-10: the numpad page's pack switcher must still cycle packs —
        // hop until the Math pack's row appears (its position in the cycle depends on
        // whatever pack a previous run left selected).
        var packHops = 0
        while !app.buttons["+"].firstMatch.exists && packHops < 12 {
            app.buttons["Switch pack"].firstMatch
                .coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            packHops += 1
            Thread.sleep(forTimeInterval: 0.5)
        }
        XCTAssertTrue(app.buttons["+"].firstMatch.exists,
                      "the numpad page's pack switcher cycles packs (Math's '+' appears)")
        attachScreenshot(named: "numpad-page")
        app.buttons["4"].firstMatch.tap()
        app.buttons["2"].firstMatch.tap()
        app.buttons["Letters"].firstMatch.tap()
        XCTAssertTrue(app.buttons["q"].waitForExistence(timeout: 3), "ABC returns to the QWERTY page")
        XCTAssertEqual(field.value as? String, "The 42", "digits typed on the numpad page landed")

        // The strip kept the Grammar selection across the page round-trip; its key types.
        XCTAssertTrue(app.buttons["\u{2014}"].waitForExistence(timeout: 3),
                      "the strip pack survives a numpad-page round trip")
        attachScreenshot(named: "qwerty-grammar-pack")
        app.buttons["\u{2014}"].firstMatch.tap()
        Thread.sleep(forTimeInterval: 0.3)
        XCTAssertEqual(field.value as? String, "The 42\u{2014}", "grammar key inserts its glyph")

        // Pack cycling must actually change the strip (owner-reported: packs didn't change when
        // selected) and wrap the whole family back to Grammar without surfacing the number line.
        app.buttons["Switch pack"].firstMatch
            .coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        Thread.sleep(forTimeInterval: 0.8)
        XCTAssertFalse(app.buttons["\u{2014}"].firstMatch.exists,
                       "one pack-switch tap moves the strip off Grammar — and it must stay moved")
        normalizeStripToGrammar(app)
        XCTAssertTrue(app.buttons["\u{2014}"].firstMatch.exists,
                      "cycling wraps the family back around to Grammar")
        attachScreenshot(named: "qwerty-pack-cycle-wrapped")

        // Layer stack (owner note #5): letters → "123" → numbers → "#+=" → secondary symbols,
        // ABC back to letters — matching the system keyboard's three pages.
        app.buttons["123"].firstMatch.tap()
        XCTAssertTrue(app.buttons["#+="].waitForExistence(timeout: 3),
                      "numbers layer offers the tertiary #+= switch, like the system keyboard")
        app.buttons["#+="].firstMatch.tap()
        XCTAssertTrue(app.buttons["€"].waitForExistence(timeout: 3),
                      "tertiary layer shows the secondary symbols (€ £ ¥ …)")
        attachScreenshot(named: "qwerty-tertiary-symbols")
        app.buttons["ABC"].firstMatch.tap()
        XCTAssertTrue(app.buttons["q"].waitForExistence(timeout: 3),
                      "ABC returns to the letters layer from the tertiary page")
    }
}
