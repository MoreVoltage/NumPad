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
    /// the keyboard by name — with tap-cycling kept as the fallback.
    @discardableResult
    private func switchToQwertyType(_ app: XCUIApplication) -> Bool {
        // includeAppButtons: no app-process button is ever labeled exactly "NumPad Type",
        // so the wider matcher set is safe here.
        switchToKeyboard(app, named: "NumPad Type", includeAppButtons: true,
                         isActive: { self.isQwertyTypeActive($0) })
    }

    /// The numpad keyboard is frontmost when its pack-switch key is present WITHOUT NumPad
    /// Type's numpad-flip key ("NumPad") — the two keyboards share the "Switch pack" label.
    private func isNumpadActive(_ app: XCUIApplication) -> Bool {
        app.buttons["Switch pack"].firstMatch.exists && !app.buttons["NumPad"].firstMatch.exists
    }

    /// Switches the active keyboard to the numpad. `includeAppButtons` must stay false: NumPad
    /// Type's own numpad-flip key is a button labeled exactly "NumPad" (with a matching inner
    /// static text), so an app-scoped exact-name query would tap the flip key instead of the
    /// picker row whenever QWERTY is frontmost.
    @discardableResult
    private func switchToNumpad(_ app: XCUIApplication) -> Bool {
        switchToKeyboard(app, named: "NumPad", includeAppButtons: false,
                         isActive: { self.isNumpadActive($0) })
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
            // firstMatch: once NumPad Type has been frontmost, BOTH its own globe key and the
            // system accessory globe carry the "Next keyboard" label. (The numpad's dedicated
            // globe is "Next Keyboard" — capital K — and never collides with this query.)
            let globe = app.buttons["Next keyboard"].firstMatch
            guard globe.waitForExistence(timeout: 4) else { break }
            globe.press(forDuration: 1.2)
            // On this runtime the picker is the app-hosted `InputSwitcherTable`, whose rows
            // are Cells labeled "<keyboard> — <app>, <language>" (observed: 'NumPad Type —
            // NumPad, English') — or "<keyboard>, <language>" when the keyboard's display
            // name equals the app's ('NumPad, English'), so an exact-name query can never
            // match them. The em-dash/comma prefixes keep "NumPad" from matching the
            // "NumPad Type — …" row. Exact-name static-text/button matchers stay as
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

    /// Settings.app enablement for the "NumPad Type" keyboard specifically, via General →
    /// Keyboard → Keyboards → Add New Keyboard — the only path that actually writes
    /// `AppleKeyboards` on this runtime. (The per-app Settings → Apps → NumPad → Keyboards
    /// switch reads ON without ever enabling the keyboard system-wide — verified against
    /// `defaults read AppleKeyboards`. The sheet's search field doesn't index third-party
    /// apps either, so the third-party section — which iPadOS puts BELOW the full language
    /// list — is reached by scrolling.)
    @discardableResult
    private func ensureQwertyTypeEnabled(includeNumpad: Bool = false) -> Bool {
        // On a fresh simulator the app-under-test is only installed by its first launch —
        // Settings can't offer keyboards for an app that isn't installed yet.
        let numpad = XCUIApplication()
        numpad.launch()
        numpad.terminate()

        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        settings.launch()
        defer { settings.terminate() }

        guard navigateToKeyboardsList(in: settings) else {
            XCTFail("ensureQwertyTypeEnabled: could not reach Settings > General > Keyboard > Keyboards")
            return false
        }

        let typeRow = settings.cells.matching(
            NSPredicate(format: "label CONTAINS 'NumPad Type'")).firstMatch
        // The numpad keyboard's list row ("NumPad — NumPad" on this runtime) — the exclusion
        // keeps "NumPad Type — NumPad" from counting as the numpad.
        let numpadRow = settings.cells.matching(NSPredicate(
            format: "label CONTAINS 'NumPad' AND NOT (label CONTAINS 'NumPad Type')")).firstMatch
        if typeRow.waitForExistence(timeout: 3), !includeNumpad || numpadRow.exists {
            return true // already enabled
        }

        let addNew = settings.descendants(matching: .any).matching(
            NSPredicate(format: "label BEGINSWITH 'Add New Keyboard'")).firstMatch
        guard addNew.waitForExistence(timeout: 5) else {
            XCTFail("ensureQwertyTypeEnabled: 'Add New Keyboard' row not found")
            return false
        }
        addNew.tap()

        // The sheet's app entry: label exactly 'NumPad', excluding the background Keyboards
        // list's enabled-keyboard row (same label, bundle-ID identifier) — and it must be
        // hittable, since the background row is covered by the sheet. iPadOS puts the
        // third-party section below every language keyboard, so swipe the sheet's own table
        // (found via its 'Other iPad/iPhone Keyboards' section) toward the bottom until the
        // entry appears.
        let appEntries = settings.cells.matching(NSPredicate(
            format: "label == 'NumPad' AND NOT (identifier CONTAINS 'com.morevoltage.NumPad.Key')"))
        func hittableAppEntry() -> XCUIElement? {
            appEntries.allElementsBoundByIndex.first { $0.isHittable }
        }
        let sheetTable = settings.tables.containing(NSPredicate(
            format: "label BEGINSWITH 'Add New Keyboard' OR identifier == 'Add New Keyboard'"))
            .firstMatch
        let scrollSurface = sheetTable.exists ? sheetTable : settings.tables.firstMatch
        var swipes = 0
        while hittableAppEntry() == nil && swipes < 30 {
            scrollSurface.swipeUp(velocity: .fast)
            swipes += 1
        }
        guard let appEntry = hittableAppEntry() else {
            attachScreenshot(named: "enable-FAILED-no-app-entry")
            XCTFail("ensureQwertyTypeEnabled: NumPad entry not found in the Add New Keyboard sheet after \(swipes) swipes")
            return false
        }
        appEntry.tap()

        // Two shapes follow the app-entry tap. With more than one of the app's keyboards
        // still disabled, a sub-page appears with one Switch per extension (identifier =
        // the extension's bundle ID) and a "Done" confirm. With a single keyboard left to
        // add, the sheet just adds it and dismisses — no sub-page, nothing to toggle
        // (observed when NumPad Type was already enabled and only the numpad was missing).
        // Either way the final Keyboards-list verification below is the real gate.
        let typeSwitch = settings.switches["com.morevoltage.NumPad.KeyboardType"].firstMatch
        let numpadSwitch = settings.switches["com.morevoltage.NumPad.Keyboard"].firstMatch
        if typeSwitch.waitForExistence(timeout: 3) || numpadSwitch.exists {
            if typeSwitch.exists, (typeSwitch.value as? String) != "1" {
                typeSwitch.switches.firstMatch.tap()
            }
            if includeNumpad, numpadSwitch.exists, (numpadSwitch.value as? String) != "1" {
                numpadSwitch.switches.firstMatch.tap()
            }
            let done = settings.buttons["Done"]
            guard done.waitForExistence(timeout: 3) else {
                XCTFail("ensureQwertyTypeEnabled: Done confirm button not found")
                return false
            }
            done.tap()
        }

        guard typeRow.waitForExistence(timeout: 5), !includeNumpad || numpadRow.waitForExistence(timeout: 3) else {
            attachScreenshot(named: "enable-FAILED-keyboards-list")
            XCTFail("ensureQwertyTypeEnabled: the added keyboard(s) did not appear in the Keyboards list")
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
        XCTAssertTrue(app.buttons["4"].firstMatch.waitForExistence(timeout: 3),
                      "numpad flip shows the digit grid")
        XCTAssertFalse(app.buttons["q"].exists, "letter rows are gone while flipped")
        // Canvas auto-swap: the strip must not duplicate the digits — with the number row
        // selected, flipping swaps the strip to the first pack (Grammar's em dash).
        XCTAssertTrue(app.buttons["\u{2014}"].firstMatch.waitForExistence(timeout: 3),
                      "number line auto-swaps to Grammar while the numpad canvas is up")
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "label == '4'")).count, 1,
                       "digits appear exactly once — never on strip and canvas together")
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

    /// The numpad must offer a button over to the full keyboard. With the pack-switch key
    /// repurposed to cycle packs (the default) and `needsInputModeSwitchKey` false on Face ID
    /// devices, the numpad used to render NO keyboard-switch key at all — only pack swapping.
    /// With NumPad Type enabled it now draws its dedicated globe ("Next Keyboard"), which also
    /// proves the extension process can read `AppleKeyboards` at runtime — the enablement
    /// signal the fix keys off.
    func testNumpadOffersGlobeWhenTypeKeyboardEnabled() throws {
        // Both siblings must be enabled: the assertion needs the numpad frontmost AND
        // NumPad Type in `AppleKeyboards` (the signal the dedicated globe keys off).
        guard ensureQwertyTypeEnabled(includeNumpad: true) else { return }

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
        guard switchToNumpad(app) else {
            attachScreenshot(named: "numpad-switch-failed")
            throw XCTSkip("could not switch the active keyboard to NumPad — keyboard-switcher automation is the documented harness gap; the globe assertion needs the numpad frontmost")
        }
        XCTAssertTrue(app.buttons["Next Keyboard"].firstMatch.waitForExistence(timeout: 4),
                      "the numpad renders its dedicated globe key when NumPad Type is enabled")
        attachScreenshot(named: "numpad-with-globe")
    }
}
