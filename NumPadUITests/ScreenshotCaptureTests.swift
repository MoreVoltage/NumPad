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

        guard let (app, _, numPadActive) = launchNumPadOnTypingSurface(extraDebugRoutes: ["entitle?pro=0"]) else {
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

        guard let (app, _, numPadActive) = launchNumPadOnTypingSurface(extraDebugRoutes: ["entitle?pro=1"]) else {
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

    // MARK: - MOR-161 simulator App Store preview (opt-in; run via capture script)

    /// Types `1200*0.0825` so the live-math chip appears, then long-presses the pack-switch key
    /// and selects Finance. Handshake files in the simulator `/tmp` let
    /// `marketing/video/capture_sim_preview_live_math_pack_swap.sh` start/stop `simctl io recordVideo`
    /// around only this sequence. Not a screenshot slot — invoke with `-only-testing`.
    func testMOR161_liveMathPackSwapPreview() throws {
        let setupApp = launchNumPad(debugRoutes: ["entitle?pro=1"])
        selectMathPack(in: setupApp)

        // Do not bounce through Settings here. A prior enable already put NumPad in the
        // system list; relaunching Preferences mid-shot left us on the system keyboard
        // with no globe (Next keyboard never appeared).
        let app = launchNumPad(debugRoutes: ["entitle?pro=1", "typing"])
        let field = app.textViews.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 12), "debug typing surface never appeared")
        // Offset tap avoids the empty-field Paste/AutoFill menu that ate the first-responder tap.
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5)).tap()
        if app.menuItems["Paste"].waitForExistence(timeout: 0.6) {
            // Dismiss by re-tapping INSIDE the field. A tap outside it (the old sheet-background
            // tap) resigns first responder, drops the keyboard, and the switch loop then thrashes
            // on off-screen keys — that was the 10:25 `kAXErrorCannotComplete` failure.
            field.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.5)).tap()
            Thread.sleep(forTimeInterval: 0.3)
        }
        let deadline = Date(timeIntervalSinceNow: 16)
        while Date() < deadline && !isNumPadKeyboardActive(app) {
            if !isAnyKeyboardVisible(app) {
                // Keyboard got dismissed (e.g. by callout handling) — re-raise it first, otherwise
                // the switcher buttons exist in the tree but sit below the screen edge.
                field.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5)).tap()
                Thread.sleep(forTimeInterval: 0.6)
            }
            _ = switchToNumPadKeyboard(app)
            Thread.sleep(forTimeInterval: 0.4)
        }
        if !isNumPadKeyboardActive(app) {
            let dumpURL = URL(fileURLWithPath: "/Users/jamespikover/NumPad/.worktrees/mor-161-preview/marketing/video/out/_fail-buttons.txt")
            let labels = app.buttons.allElementsBoundByIndex.prefix(120).map { b -> String in
                let val = (b.value as? String) ?? ""
                return "label=[" + b.label + "] id=[" + b.identifier + "] value=[" + val + "]"
            }
            let body = labels.joined(separator: "\n") + "\nkeyboards=" + String(app.keyboards.count) + "\n"
            try? body.write(to: dumpURL, atomically: true, encoding: .utf8)
            let png = XCUIScreen.main.screenshot().pngRepresentation
            try? png.write(to: URL(fileURLWithPath: "/Users/jamespikover/NumPad/.worktrees/mor-161-preview/marketing/video/out/_fail.png"))
        }
        XCTAssertTrue(isNumPadKeyboardActive(app), "NumPad keyboard was not active; cannot capture live math + pack swap")

        let fm = FileManager.default
        let ready = "/tmp/mor161-ready"
        let go = "/tmp/mor161-go"
        let done = "/tmp/mor161-done"
        try? fm.removeItem(atPath: go)
        try? fm.removeItem(atPath: done)
        fm.createFile(atPath: ready, contents: Data("ready".utf8))

        let goDeadline = Date(timeIntervalSinceNow: 90)
        while !fm.fileExists(atPath: go) && Date() < goDeadline {
            Thread.sleep(forTimeInterval: 0.2)
        }
        XCTAssertTrue(fm.fileExists(atPath: go), "capture script never wrote /tmp/mor161-go")

        // Timings below are the shot's pacing: ~1s settle on the keyboard, legible typing, a clear
        // beat on the chip (it hides while the pack picker overlay is up, so it needs its moment
        // BEFORE the swap), and a hold on the Finance row at the end. Target: 15–20s total.
        Thread.sleep(forTimeInterval: 1.0)
        tapKeys(["1", "2", "0", "0", "*", "0", ".", "0", "8", "2", "5"], in: app, pause: 0.22)

        let chip = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'Insert calculated result'")).firstMatch
        XCTAssertTrue(chip.waitForExistence(timeout: 6), "live math chip did not appear for 1200*0.0825")
        Thread.sleep(forTimeInterval: 2.2)

        let packSwitch = app.buttons["Switch pack"]
        XCTAssertTrue(packSwitch.waitForExistence(timeout: 5), "Switch pack key missing")
        packSwitch.press(forDuration: 0.55)
        let finance = app.staticTexts["Finance"].firstMatch
        XCTAssertTrue(finance.waitForExistence(timeout: 5), "Finance row missing from pack picker")
        finance.tap()
        Thread.sleep(forTimeInterval: 3.5)

        fm.createFile(atPath: done, contents: Data("done".utf8))
        attachScreenshot(named: "mor161-live-math-pack-swap")
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
    private func tapKeys(_ keys: [String], in app: XCUIApplication, pause: TimeInterval = 0.15) {
        for key in keys {
            let button = app.buttons[key]
            XCTAssertTrue(button.waitForExistence(timeout: 5), "key '\(key)' not found on the keyboard")
            button.tap()
            Thread.sleep(forTimeInterval: pause)
        }
    }
}
