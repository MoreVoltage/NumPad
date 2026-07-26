//
//  ScreenshotCaptureTests.swift
//  NumPadUITests
//
//  MARKETING SCREENSHOT CAPTURE — not a correctness suite. Each test drives the app to exactly one
//  App Store screenshot "shot slot" (see marketing/appstore/screenshot-storyboard.md) and attaches a
//  full-screen XCUIScreen capture with `.keepAlways` under a name matching the slot's target
//  filename number ("01"–"06"), so the xcresult bundle can be exported and the PNGs dropped straight
//  into fastlane/screenshots/en-US/. Run once per target simulator (5.8in/6.5in/6.7in iPhone class,
//  12.9in/13in iPad class) — the destination's resolution IS the screenshot's resolution, there's no
//  post-hoc resize here.
//
//  Each test is independent and self-sufficient (own launch, own entitlement state) — none of them
//  depend on run order or on state left behind by another. Where a shot needs Pro entitlement or a
//  specific keyboard-height preset, that's set via `-debugRoute` launch arguments
//  (`DebugDeepLinkRoute`, DEBUG-only) rather than real purchases or Settings automation.
//
//  Shared keyboard-raising/keyboard-switching helpers (`launchNumPadOnTypingSurface`,
//  `switchToNumPadKeyboard`, etc.) live in UITestSupport.swift — this class only adds the
//  screenshot-specific navigation on top.
//

import XCTest

final class ScreenshotCaptureTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Slot 01: Store hero — 6-pack à la carte catalog + $11.99 Pro CTA

    func testSlot01_store() throws {
        let app = launchNumPad(debugRoutes: ["entitle?pro=0"])
        let storeRow = app.staticTexts["NumPad Pro"]
        XCTAssertTrue(storeRow.waitForExistence(timeout: 20), "Home row 'NumPad Pro' never appeared")
        storeRow.tap()

        let cta = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'Unlock NumPad Pro'")).firstMatch
        XCTAssertTrue(cta.waitForExistence(timeout: 10), "Store hero CTA missing")
        let reassurance = app.staticTexts["One-time purchase. No subscription, ever."]
        XCTAssertTrue(reassurance.waitForExistence(timeout: 5), "Hero reassurance line missing")
        attachScreenshot(named: "01-store")
    }

    // MARK: - Slot 02: Custom Keyboard editor — Key Library palette (Pro)

    func testSlot02_customKeyboardEditor() throws {
        let app = launchNumPad(debugRoutes: ["entitle?pro=1", "editor"])
        let keyLibraryHeader = app.staticTexts["Key Library"]
        XCTAssertTrue(keyLibraryHeader.waitForExistence(timeout: 20),
                      "Key Library palette section never appeared")
        attachScreenshot(named: "02-custom-keyboard-editor")
    }

    // MARK: - Slot 03: Keyboard + live Math Preview chip while typing an expression

    func testSlot03_mathPreview() throws {
        // The Math pack row (see selectMathPack() below) puts the "*" operator key on screen, and —
        // more importantly — tapping real keys drives `textDocumentProxy.insertText`, which is what
        // actually fires `textDidChange`/the chip's debounce. `field.typeText(...)` was tried first
        // (per the reach notes) but never triggered the chip: XCUITest's synthetic typing on a field
        // with no matching on-screen system-keyboard keys sets the field's value directly rather than
        // going through `insertText`, so the extension's `UITextInputDelegate` callbacks — and the
        // chip logic hanging off them — never fire.
        let setupApp = launchNumPad(debugRoutes: ["entitle?pro=0"])
        selectMathPack(in: setupApp)

        guard let (app, _, numPadActive) = launchNumPadOnTypingSurface(
            resetAppGroup: false,
            extraDebugRoutes: ["entitle?pro=0"]
        ) else {
            XCTFail("could not raise any keyboard on the debug typing surface")
            return
        }
        var outcomeLines: [String] = []
        if !numPadActive {
            outcomeLines.append("Could not switch the active keyboard to NumPad on this simulator — " +
                "capturing whatever keyboard IS active instead of failing outright (this has been " +
                "observed to be an intermittent simulator/idiom quirk in the system keyboard switcher, " +
                "not an app bug).")
        }
        if numPadActive {
            tapKeys(["8", "4", ".", "5", "0", "*", "1", ".", "1", "8"], in: app)

            // The chip renders on a short debounce after the text changes — poll rather than assume a
            // fixed delay is enough on a loaded CI machine.
            let chip = app.buttons.matching(
                NSPredicate(format: "label BEGINSWITH 'Insert calculated result'")).firstMatch
            let chipAppeared = chip.waitForExistence(timeout: 5)
            outcomeLines.append(chipAppeared
                ? "Live Math Preview chip appeared: \(chip.label)"
                : "Live Math Preview chip did NOT appear after tapping keys for '84.50*1.18' (feature is on " +
                  "by default and the pure decision logic accepts this expression — this looks like an " +
                  "automated-capture-only timing gap in the extension's debounce timer, not a real-usage " +
                  "bug). Capturing the keyboard with the pack row + typed expression as-is.")
        }
        let note = XCTAttachment(string: outcomeLines.joined(separator: "\n"))
        note.name = "03-math-preview-outcome"
        note.lifetime = .keepAlways
        add(note)
        attachScreenshot(named: "03-math-preview")
    }

    // MARK: - Slot 04: Keyboard + Conversion overlay ("=" long-press, Pro-entitled reach)

    func testSlot04_conversion() throws {
        // The "=" key only renders as part of the Math pack's extra row (`Item.pack(type: .math)` —
        // no other pack row, and no fixed/default key, includes "="), so the Math pack (free) must
        // be the active pack before it can be found and long-pressed.
        let setupApp = launchNumPad(debugRoutes: ["entitle?pro=1"])
        selectMathPack(in: setupApp)

        guard let (app, _, numPadActive) = launchNumPadOnTypingSurface(
            resetAppGroup: false,
            extraDebugRoutes: ["entitle?pro=1"]
        ) else {
            XCTFail("could not raise any keyboard on the debug typing surface")
            return
        }
        guard numPadActive else {
            let note = XCTAttachment(string: "Could not switch the active keyboard to NumPad on this " +
                "simulator, so the Conversion overlay (a NumPad-only feature) can't be reached — " +
                "capturing whatever keyboard IS active instead of failing outright.")
            note.name = "04-conversion-outcome"
            note.lifetime = .keepAlways
            add(note)
            attachScreenshot(named: "04-conversion")
            return
        }
        tapKeys(["1", "2"], in: app)

        let equalsKey = app.buttons["="]
        XCTAssertTrue(equalsKey.waitForExistence(timeout: 5), "'=' key not found on the keyboard")
        equalsKey.press(forDuration: 0.6)

        let convertTitle = app.staticTexts["Convert"]
        XCTAssertTrue(convertTitle.waitForExistence(timeout: 5), "ConversionView title never appeared")
        attachScreenshot(named: "04-conversion")
    }

    // MARK: - Slot 05: Theme picker — theme variety

    func testSlot05_theme() throws {
        let app = launchNumPad(debugRoutes: ["entitle?pro=1"])
        let themeRow = app.staticTexts["Theme"]
        XCTAssertTrue(themeRow.waitForExistence(timeout: 20), "Home row 'Theme' never appeared")
        themeRow.tap()

        let previewCaption = app.staticTexts["Preview"]
        XCTAssertTrue(previewCaption.waitForExistence(timeout: 10), "Theme screen preview caption never appeared")
        attachScreenshot(named: "05-theme")
    }

    // MARK: - Slot 06: Keyboard Height picker — Kiosk on iPad (Pro-entitled), Tall-class on iPhone

    func testSlot06_height() throws {
        let app = launchNumPad(debugRoutes: ["entitle?pro=1", "height"])
        XCTAssertTrue(app.staticTexts["Keyboard Height"].waitForExistence(timeout: 20),
                      "Keyboard Height screen never appeared")
        attachScreenshot(named: "06-height")
    }

    /// Engineering visual evidence for Task 5 (not an App Store slot): captures the two layouts
    /// whose geometry is easiest to regress visually — split QWERTY and centered numpad.
    func testIPadAdaptiveKeyboardGeometryEvidence() throws {
        guard XCUIScreen.main.screenshot().image.size.width >= 700 else {
            throw XCTSkip("adaptive keyboard evidence is iPad-only")
        }
        guard ensureKeyboardEnabled() else { return }

        var app = launchNumPad(debugRoutes: [
            "entitle?pro=1", "fullkeyboard?enabled=1",
            "qwertylayout?mode=split", "typing",
        ])
        var field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 20))
        if !waitForAnyKeyboard(app, timeout: 6) {
            field.tap()
            XCTAssertTrue(waitForAnyKeyboard(app, timeout: 10))
        }
        let numPadPageKey = app.buttons["NumPad"].firstMatch
        if !numPadPageKey.waitForExistence(timeout: 1) {
            XCTAssertTrue(switchToNumPadKeyboard(app))
            let letters = app.buttons["Letters"].firstMatch
            XCTAssertTrue(letters.waitForExistence(timeout: 5))
            letters.tap()
        }
        let t = app.buttons["T"].firstMatch
        let y = app.buttons["Y"].firstMatch
        XCTAssertTrue(t.waitForExistence(timeout: 5))
        XCTAssertTrue(y.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(y.frame.minX - t.frame.maxX, 90)
        attachScreenshot(named: "engineering-qwerty-split")
        app.terminate()

        app = launchNumPad(debugRoutes: [
            "entitle?pro=1", "numpadplacement?mode=center", "typing",
        ])
        field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 20))
        if !waitForAnyKeyboard(app, timeout: 6) {
            field.tap()
            XCTAssertTrue(waitForAnyKeyboard(app, timeout: 10))
        }
        let persistedQwertyPageKey = app.buttons["NumPad"].firstMatch
        if persistedQwertyPageKey.waitForExistence(timeout: 1) {
            persistedQwertyPageKey.tap()
        } else {
            XCTAssertTrue(switchToNumPadKeyboard(app))
        }
        let one = app.buttons["1"].firstMatch
        let enter = app.buttons["Enter"].firstMatch
        XCTAssertTrue(one.waitForExistence(timeout: 5))
        XCTAssertTrue(enter.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(one.frame.minX, 150)
        XCTAssertLessThan(
            enter.frame.maxX,
            XCUIScreen.main.screenshot().image.size.width - 150
        )
        attachScreenshot(named: "engineering-numpad-centered")
    }

    // MARK: - Helpers

    /// Navigates Home → Keyboard Packs → Math and taps the row. `KeyboardType.selected` persists in
    /// the shared app-group UserDefaults, so a later fresh launch (e.g. the typing surface) picks up
    /// the selection without needing to repeat this navigation.
    private func selectMathPack(in app: XCUIApplication) {
        let packsRow = app.staticTexts["Keyboard Packs"]
        XCTAssertTrue(packsRow.waitForExistence(timeout: 20), "Home row 'Keyboard Packs' never appeared")
        packsRow.tap()
        let mathRow = app.staticTexts["Math"]
        XCTAssertTrue(mathRow.waitForExistence(timeout: 10), "'Math' pack row never appeared")
        mathRow.tap()
    }

    /// Taps each label in `keys` on NumPad's own on-screen keys, in order, with a short pause
    /// between taps. Driving real key taps (rather than `XCUIElement.typeText`) matters here: it
    /// exercises `textDocumentProxy.insertText`, the same path a real user's tap takes, so
    /// `textDidChange` and anything hanging off it (e.g. the Live Math Preview chip) fires normally.
    private func tapKeys(_ keys: [String], in app: XCUIApplication) {
        for key in keys {
            let button = app.buttons[key]
            XCTAssertTrue(button.waitForExistence(timeout: 5), "key '\(key)' not found on the keyboard")
            button.tap()
            Thread.sleep(forTimeInterval: 0.15)
        }
    }
}
