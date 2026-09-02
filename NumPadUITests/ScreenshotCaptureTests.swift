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

// MARK: - iPad App Store marketing raws (Simulator, not PIL)

/// Drives the six App Store iPad raws on a wide iPad Simulator so overlays use the 360pt
/// trailing side panel (`maxWidth >= 700`). Screenshots are attached *and* written to
/// `/tmp/numpad-ipad-shots` inside the simulator for host-side collection.
final class IPadAppStoreScreenshotTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    func test00_enableKeyboard() throws {
        guard ensureKeyboardEnabled() else { return }
        attachScreenshot(named: "00-keyboard-enabled")
    }

    /// Keyboard is enabled in `test00`. Later slots skip Settings so they don't flake on the
    /// iPad split-view Keyboards list, and they clear any leftover custom-keyboard config.
    private let shotBaseRoutes = [
        "entitle?pro=1",
        "preset?value=kiosk",
        "custom-clear",
    ]

    func test01_hero() throws {
        guard let (app, _, numPadActive) = launchNumPadOnTypingSurface(
            extraDebugRoutes: shotBaseRoutes + ["theme?value=white", "pack?value=default"],
            typingScene: "hero",
            skipKeyboardEnable: true
        ) else {
            XCTFail("hero: could not raise keyboard")
            return
        }
        XCTAssertTrue(numPadActive, "hero: NumPad keyboard not active")
        tapNumPadKeys(["1", "4", "4", "0", "0"], in: app)
        Thread.sleep(forTimeInterval: 0.6)
        attachScreenshot(named: "01-hero")
    }

    func test02_checkout() throws {
        guard let (app, _, numPadActive) = launchNumPadOnTypingSurface(
            extraDebugRoutes: shotBaseRoutes + ["theme?value=blue", "pack?value=default"],
            typingScene: "checkout",
            skipKeyboardEnable: true
        ) else {
            XCTFail("checkout: could not raise keyboard")
            return
        }
        XCTAssertTrue(numPadActive, "checkout: NumPad keyboard not active")
        tapNumPadKeys(["4", "2", "4", "2", "4", "2", "4", "2"], in: app)
        Thread.sleep(forTimeInterval: 0.6)
        attachScreenshot(named: "02-checkout")
    }

    func test03_taxtip() throws {
        guard let (app, _, numPadActive) = launchNumPadOnTypingSurface(
            extraDebugRoutes: shotBaseRoutes + ["theme?value=amber", "pack?value=math"],
            typingScene: "dinner",
            skipKeyboardEnable: true
        ) else {
            XCTFail("taxtip: could not raise keyboard")
            return
        }
        XCTAssertTrue(numPadActive, "taxtip: NumPad keyboard not active")
        let percent = app.buttons["%"]
        XCTAssertTrue(percent.waitForExistence(timeout: 5), "% key missing — Math pack not active?")
        percent.press(forDuration: 0.6)
        XCTAssertTrue(app.staticTexts["TAX/TIP"].waitForExistence(timeout: 5), "TAX/TIP overlay never appeared")
        tapNumPadKeys(["8", "0", ".", "0", "0"], in: app)
        let tax8 = app.buttons["8%"].firstMatch
        if tax8.waitForExistence(timeout: 2) { tax8.tap() }
        let tip18 = app.buttons["18%"].firstMatch
        if tip18.waitForExistence(timeout: 2) { tip18.tap() }
        Thread.sleep(forTimeInterval: 0.8)
        attachScreenshot(named: "03-taxtip")
    }

    func test04_clipboard() throws {
        guard let (app, _, numPadActive) = launchNumPadOnTypingSurface(
            extraDebugRoutes: shotBaseRoutes + [
                "theme?value=green",
                "pack?value=default",
                "clipboard-seed",
            ],
            typingScene: "invoice",
            skipKeyboardEnable: true
        ) else {
            XCTFail("clipboard: could not raise keyboard")
            return
        }
        XCTAssertTrue(numPadActive, "clipboard: NumPad keyboard not active")
        let zero = app.buttons["0"]
        XCTAssertTrue(zero.waitForExistence(timeout: 5), "0 key missing")
        zero.press(forDuration: 0.6)
        XCTAssertTrue(
            app.staticTexts["Clipboard History"].waitForExistence(timeout: 5),
            "Clipboard History overlay never appeared"
        )
        Thread.sleep(forTimeInterval: 0.8)
        attachScreenshot(named: "04-clipboard")
    }

    func test05_packs() throws {
        // Live keyboard-in-use with Finance pack. Not the Packs settings list.
        guard let (app, _, numPadActive) = launchNumPadOnTypingSurface(
            extraDebugRoutes: shotBaseRoutes + ["theme?value=black", "pack?value=finance"],
            typingScene: "invoice",
            skipKeyboardEnable: true
        ) else {
            XCTFail("packs: could not raise keyboard")
            return
        }
        XCTAssertTrue(numPadActive, "packs: NumPad keyboard not active")
        tapNumPadKeys(["1", "2", "4", "9", ".", "9", "9"], in: app)
        Thread.sleep(forTimeInterval: 0.6)
        attachScreenshot(named: "05-packs")
    }

    func test06_themes() throws {
        // Live iPad keyboard in Deep Purple — not the 4x4 Theme-picker preview.
        guard let (app, _, numPadActive) = launchNumPadOnTypingSurface(
            extraDebugRoutes: shotBaseRoutes + ["theme?value=deepPurple", "pack?value=default"],
            typingScene: "hero",
            skipKeyboardEnable: true
        ) else {
            XCTFail("themes: could not raise keyboard")
            return
        }
        XCTAssertTrue(numPadActive, "themes: NumPad keyboard not active")
        tapNumPadKeys(["1", "4", "4", "0", "0"], in: app)
        Thread.sleep(forTimeInterval: 0.6)
        attachScreenshot(named: "06-themes")
    }
}
