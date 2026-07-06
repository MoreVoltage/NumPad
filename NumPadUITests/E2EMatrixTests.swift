//
//  E2EMatrixTests.swift
//  NumPadUITests
//
//  The full iPad E2E matrix. Method names are numbered because XCTest runs a class's tests in
//  alphabetical selector order, but ordering between methods is NOT a dependency contract here:
//   - test01 exercises Settings.app enablement explicitly (and best-effort Full Access) as its own
//     test, but every keyboard-dependent test (07–10) also calls the shared
//     `ensureKeyboardEnabled()` helper (see UITestSupport.swift) itself before doing anything else,
//     so none of them depend on test01 having run — let alone passed — first. Neither
//     `simctl openurl` (undismissable confirm dialog) nor the AppleKeyboards defaults-write trick
//     enables a third-party keyboard on this runtime, so driving Settings.app's UI is the only way.
//   - test07–test09 each raise the keyboard at one height preset and record its measured height.
//     test10 is self-sufficient: it gathers all four measurements itself (small/regular/tall/kiosk)
//     rather than reading state left behind by 07–09, so it asserts the strictly-increasing
//     ordering correctly even if run alone or if an earlier test in the class failed.
//  Every test attaches `.keepAlways` screenshots so the visual record survives green runs.
//
//  Known side effect, accepted deliberately: test05's chip drag (when it succeeds) saves a custom
//  keyboard config through the editor's write-through model, so the typing tests that follow render
//  the custom-keyboard layout (numpad + side column) rather than the plain pack layout. Height
//  presets are independent of that layout, so the height assertions are unaffected — and it means
//  the height screenshots double as custom-keyboard-at-iPad-width renders.
//

import XCTest

final class E2EMatrixTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - test01: enable the NumPad keyboard via Settings.app (idempotent)

    func test01_enableKeyboardInSettings() throws {
        // Idempotent core: PASS immediately (after the screenshot) if NumPad is already enabled —
        // no Full Access dance, no alerts, nothing else that could flake on an already-green fast
        // path. `ensureKeyboardEnabled` (UITestSupport.swift) is the single source of truth shared
        // with test07–test10, so this test can never diverge from what they rely on.
        guard ensureKeyboardEnabled() else { return } // failure already reported with a clear message
        attachScreenshot(named: "01-settings-keyboard-enabled")

        // Best-effort Full Access, as its own step, kept out of the pass/fail path above: not
        // required by any later test (height/clipboard-free flows don't need it), so nothing in
        // here uses XCTAssert/XCTFail — it can only degrade gracefully, never fail this test.
        attemptEnableFullAccess()
    }

    /// Turns on "Allow Full Access" for the NumPad keyboard row, if present. Best-effort only: the
    /// confirmation alert this triggers can be owned by either the Settings process or SpringBoard
    /// depending on runtime, so this checks both directly, plus registers a `UIInterruptionMonitor`
    /// (the standard XCUITest mechanism for alerts presented by a different process than the one
    /// under direct test) as a third line of defense — with generous waits throughout, since the
    /// alert's presenting process can take a beat to hand off.
    private func attemptEnableFullAccess() {
        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        settings.launch()
        defer { settings.terminate() }

        guard navigateToKeyboardsList(in: settings) else {
            attachScreenshot(named: "01-settings-full-access-unreachable")
            return
        }
        let numpadRow = settings.cells.matching(
            NSPredicate(format: "label CONTAINS 'NumPad'")).firstMatch
        guard numpadRow.waitForExistence(timeout: 5) else {
            attachScreenshot(named: "01-settings-full-access-unreachable")
            return
        }
        numpadRow.tap()

        let fullAccess = settings.switches.matching(
            NSPredicate(format: "label CONTAINS 'Full Access'")).firstMatch
        guard fullAccess.waitForExistence(timeout: 5) else {
            attachScreenshot(named: "01-settings-full-access-unreachable")
            return
        }
        if (fullAccess.value as? String) == "1" {
            attachScreenshot(named: "01-settings-full-access")
            return
        }

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let monitor = addUIInterruptionMonitor(withDescription: "NumPad Full Access confirmation") { alert in
            let allow = alert.buttons["Allow"].firstMatch
            guard allow.exists else { return false }
            allow.tap()
            return true
        }
        defer { removeUIInterruptionMonitor(monitor) }

        fullAccess.tap()
        // The interruption monitor above only fires on the *next* UI interaction, so make a
        // harmless one now to give XCTest a chance to detect and dismiss a blocking alert.
        settings.tap()

        // Fall back to direct queries in case the monitor already handled it, missed it, or the
        // alert is scoped to a process it doesn't intercept on this runtime.
        let appAllow = settings.alerts.buttons["Allow"].firstMatch
        let sbAllow = springboard.alerts.buttons["Allow"].firstMatch
        if appAllow.waitForExistence(timeout: 5) {
            appAllow.tap()
        } else if sbAllow.waitForExistence(timeout: 5) {
            sbAllow.tap()
        }
        attachScreenshot(named: "01-settings-full-access")
    }

    // MARK: - test02: Home

    func test02_home() throws {
        let app = launchNumPad(debugRoutes: ["entitle?pro=0"])
        XCTAssertTrue(app.staticTexts["NumPad Pro"].waitForExistence(timeout: 20),
                      "Home table (NumPad Pro row) never appeared")
        XCTAssertTrue(app.staticTexts["Keyboard Packs"].exists)
        XCTAssertTrue(app.staticTexts["Custom Keyboard"].exists)
        attachScreenshot(named: "02-home")
    }

    // MARK: - test03: Store (hero fully composed, no truncation)

    func test03_store() throws {
        let app = launchNumPad(debugRoutes: ["entitle?pro=0"])
        let storeRow = app.staticTexts["NumPad Pro"]
        XCTAssertTrue(storeRow.waitForExistence(timeout: 20))
        storeRow.tap()

        // CTA (top-to-bottom the last full-width hero block) + the reassurance line UNDER the CTA:
        // both existing proves the hero composed to its full height instead of collapsing/truncating
        // (the pre-fix failure mode was a near-zero-height hero).
        let cta = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'Unlock NumPad Pro'")).firstMatch
        XCTAssertTrue(cta.waitForExistence(timeout: 10), "Store hero CTA missing")
        let reassurance = app.staticTexts["One-time purchase. No subscription, ever."]
        XCTAssertTrue(reassurance.waitForExistence(timeout: 5), "Hero reassurance line missing")
        attachScreenshot(named: "03-store-hero")
    }

    // MARK: - test04: Height picker, locked then entitled

    func test04_heightPicker_lockedThenEntitled() throws {
        // Locked: Kiosk row present (iPad-only) but lock-adorned; selecting it would deep-link to
        // the store — not exercised here to keep the screen state clean for the screenshot.
        var app = launchNumPad(debugRoutes: ["entitle?pro=0", "height"])
        XCTAssertTrue(app.staticTexts["Keyboard Height"].waitForExistence(timeout: 20),
                      "Keyboard Height screen never appeared")
        XCTAssertTrue(app.staticTexts["Kiosk"].waitForExistence(timeout: 5),
                      "Kiosk preset row missing — expected on iPad")
        attachScreenshot(named: "04a-height-picker-locked")

        // Entitled: relaunch with the pro override; selecting Kiosk must stay on this screen
        // (no store push) and take the selection.
        app = launchNumPad(debugRoutes: ["entitle?pro=1", "height"])
        XCTAssertTrue(app.staticTexts["Keyboard Height"].waitForExistence(timeout: 20))
        let kiosk = app.staticTexts["Kiosk"]
        XCTAssertTrue(kiosk.waitForExistence(timeout: 5))
        kiosk.tap()
        let storeCTA = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'Unlock NumPad Pro'")).firstMatch
        XCTAssertFalse(storeCTA.waitForExistence(timeout: 2),
                       "Selecting Kiosk while entitled must not deep-link to the store")
        XCTAssertTrue(app.staticTexts["Keyboard Height"].exists)
        attachScreenshot(named: "04b-height-picker-entitled-kiosk-selected")
    }

    // MARK: - test05: Custom Keyboard editor (palette + honest drag attempt)

    func test05_editor() throws {
        let app = launchNumPad(debugRoutes: ["entitle?pro=1", "editor"])

        let keyLibraryHeader = app.staticTexts["Key Library"]
        XCTAssertTrue(keyLibraryHeader.waitForExistence(timeout: 20),
                      "Key Library palette section never appeared (drag-reorder kill switch off?)")
        attachScreenshot(named: "05a-editor-palette")

        // Drag attempt: a curated-character chip onto an empty slot rendered by
        // CustomKeyboardSectionReorderView (accessibility label "Empty slot"). Column 1 is seeded
        // from the right-side slots on first open, so empty padding slots normally exist; if not,
        // tick "Row 1" to create some. The chip is chosen dynamically as one whose label appears
        // exactly once on screen (palette only, not yet assigned to any slot) so the +1-cell
        // verification below stays valid on reruns against a persisted config from a prior run.
        var emptySlot = app.cells.matching(NSPredicate(format: "label == 'Empty slot'")).firstMatch
        if !emptySlot.waitForExistence(timeout: 3) {
            let rowCheckbox = app.staticTexts["Row 1"]
            if rowCheckbox.exists { rowCheckbox.tap() }
            emptySlot = app.cells.matching(NSPredicate(format: "label == 'Empty slot'")).firstMatch
        }
        let chipLabel = ["€", "#", "(", ")", "$", "%"].first { label in
            app.cells.matching(NSPredicate(format: "label == %@", label)).count == 1
        }

        var dragOutcome = "not attempted"
        if let chipLabel,
           emptySlot.waitForExistence(timeout: 3) {
            let chipQuery = app.cells.matching(NSPredicate(format: "label == %@", chipLabel))
            let chip = chipQuery.firstMatch
            // Slow drag + hold before release: UICollectionView drag & drop needs the lift to
            // register and the drop proposal to settle, or the session cancels (observed flaky
            // with the plain two-argument press-drag).
            chip.press(forDuration: 1.0, thenDragTo: emptySlot,
                       withVelocity: .slow, thenHoldForDuration: 0.5)
            Thread.sleep(forTimeInterval: 1.5)
            let cellsAfter = chipQuery.count
            dragOutcome = cellsAfter > 1
                ? "SUCCESS — '\(chipLabel)' chip landed in a slot (1 → \(cellsAfter) cells)"
                : "FAILED — drop did not assign (still \(cellsAfter) '\(chipLabel)' cell)"
            attachScreenshot(named: "05b-editor-after-drag-attempt")
        } else {
            dragOutcome = "not attempted — no unassigned chip or no empty slot in the accessibility tree"
        }
        let note = XCTAttachment(string: "Chip drag outcome: \(dragOutcome)")
        note.name = "05-drag-outcome"
        note.lifetime = .keepAlways
        add(note)
        NSLog("[E2EMatrix] test05 drag outcome: \(dragOutcome)")
    }

    // MARK: - test06: Features & Guide

    func test06_guide() throws {
        let app = launchNumPad(debugRoutes: ["guide"])
        XCTAssertTrue(app.staticTexts["Features & Guide"].waitForExistence(timeout: 20),
                      "Features & Guide screen never appeared")
        XCTAssertTrue(app.staticTexts["Getting Started"].waitForExistence(timeout: 5))
        attachScreenshot(named: "06-guide")
    }

    // MARK: - test07–test10: keyboard at each height preset

    func test07_keyboardAtHeightSmall() throws {
        try measureKeyboardHeight(preset: "small", pro: false, screenshotName: "07-keyboard-small")
    }

    func test08_keyboardAtHeightRegular() throws {
        try measureKeyboardHeight(preset: "regular", pro: false, screenshotName: "08-keyboard-regular")
    }

    func test09_keyboardAtHeightTall() throws {
        try measureKeyboardHeight(preset: "tall", pro: false, screenshotName: "09-keyboard-tall")
    }

    func test10_keyboardAtHeightKiosk_heightsStrictlyIncrease() throws {
        // Self-sufficient: gathers all four measurements itself rather than reading state left
        // behind by test07–test09, so this assertion holds even if this test runs alone or an
        // earlier test in the class failed/was skipped.
        let small = try measureKeyboardHeight(preset: "small", pro: false,
                                              screenshotName: "10-keyboard-small")
        let regular = try measureKeyboardHeight(preset: "regular", pro: false,
                                                screenshotName: "10-keyboard-regular")
        let tall = try measureKeyboardHeight(preset: "tall", pro: false,
                                             screenshotName: "10-keyboard-tall")
        let kiosk = try measureKeyboardHeight(preset: "kiosk", pro: true,
                                              screenshotName: "10-keyboard-kiosk")

        NSLog("[E2EMatrix] measured heights: small=\(small) regular=\(regular) tall=\(tall) kiosk=\(kiosk)")
        let note = XCTAttachment(
            string: "small=\(small) regular=\(regular) tall=\(tall) kiosk=\(kiosk)")
        note.name = "10-measured-heights"
        note.lifetime = .keepAlways
        add(note)
        XCTAssertLessThan(small, regular, "small must be shorter than regular")
        XCTAssertLessThan(regular, tall, "regular must be shorter than tall")
        XCTAssertLessThan(tall, kiosk, "tall must be shorter than kiosk (Pro-entitled)")
    }

    // MARK: - Helpers
    //
    // `tapRow`, `navigateToKeyboardsList`, and `ensureKeyboardEnabled` live in UITestSupport.swift
    // — shared with test01 and every keyboard-dependent test below.

    /// True when the frontmost keyboard is NumPad. IMPORTANT: on this runtime a custom keyboard
    /// extension exposes NO `XCUIElementType.keyboard` element at all — its keys are plain
    /// `.button`s from the extension process, merged into the host app's tree under anonymous
    /// `Other`s (verified via a failure-time hierarchy dump). So this must query app-wide for
    /// NumPad's own distinctive keys, never inside `app.keyboards` (which only ever matches the
    /// SYSTEM keyboard here). "Next Keyboard" (the globe key's label, capital K) and "Enter" only
    /// coexist on NumPad's bottom row.
    private func isNumPadKeyboardActive(_ app: XCUIApplication) -> Bool {
        app.buttons["Next Keyboard"].exists && app.buttons["Enter"].exists
    }

    /// True when ANY keyboard is up: NumPad (no `.keyboard` element — see above), the system
    /// keyboard (`app.keyboards`), or the host-side `inputView` container that wraps whichever
    /// input view is showing.
    private func isAnyKeyboardVisible(_ app: XCUIApplication) -> Bool {
        isNumPadKeyboardActive(app)
            || app.keyboards.firstMatch.exists
            || app.otherElements["inputView"].firstMatch.exists
    }

    /// Polls for `isAnyKeyboardVisible` — there is no single element to `waitForExistence` on,
    /// because the three signals live in different parts of the tree.
    @discardableResult
    private func waitForAnyKeyboard(_ app: XCUIApplication, timeout: TimeInterval) -> Bool {
        let deadline = Date(timeIntervalSinceNow: timeout)
        while Date() < deadline {
            if isAnyKeyboardVisible(app) { return true }
            Thread.sleep(forTimeInterval: 0.5)
        }
        return isAnyKeyboardVisible(app)
    }

    /// Switches the active keyboard to NumPad. Preferred path: long-press the system keyboard's
    /// "Next keyboard" globe and pick NumPad from the input-switcher menu; fallback: single-tap the
    /// globe to cycle input modes, re-checking the NumPad signature each time. The menu predicate
    /// excludes "Pro" so it can never match the Home screen's "NumPad Pro" row showing through the
    /// typing sheet.
    @discardableResult
    private func switchToNumPadKeyboard(_ app: XCUIApplication) -> Bool {
        if isNumPadKeyboardActive(app) { return true }
        // Only the SYSTEM keyboard has a `.keyboard` element and a "Next keyboard" globe to drive;
        // once NumPad takes over, that element vanishes and this loop's exit check fires instead.
        // Both existence checks below WAIT rather than snapshot-check instantly: on a cold app
        // launch the debug typing surface's `becomeFirstResponder` can satisfy
        // `waitForAnyKeyboard` (e.g. via the `inputView` container appearing first) slightly before
        // the system keyboard's own `.keyboard` element and globe button finish rendering — an
        // instant `.exists` there raced that and `break`-exited the loop before a single switch
        // attempt, always failing on the very first keyboard-dependent test after a fresh launch.
        let keyboard = app.keyboards.firstMatch
        let menuPredicate = NSPredicate(
            format: "label CONTAINS 'NumPad' AND NOT (label CONTAINS 'Pro') AND NOT (label CONTAINS 'debug')")
        for _ in 0..<5 {
            guard keyboard.waitForExistence(timeout: 3) else { break }
            let globe = keyboard.buttons["Next keyboard"]
            guard globe.waitForExistence(timeout: 2) else { break }
            globe.press(forDuration: 1.2)
            let menuOption = app.tables.staticTexts.matching(menuPredicate).firstMatch
            let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
            let sbOption = springboard.staticTexts.matching(menuPredicate).firstMatch
            if menuOption.waitForExistence(timeout: 2) {
                menuOption.tap()
            } else if sbOption.waitForExistence(timeout: 1) {
                sbOption.tap()
            } else if globe.exists {
                globe.tap() // no queryable menu — plain tap cycles to the next input mode
            }
            Thread.sleep(forTimeInterval: 1.0)
            if isNumPadKeyboardActive(app) { return true }
        }
        return isNumPadKeyboardActive(app)
    }

    /// Launches with the given preset (+ pro override), raises the keyboard on the debug typing
    /// surface, ensures NumPad is the active keyboard, screenshots, and records the measured
    /// keyboard height for the test10 ordering assertion.
    ///
    /// Calls `ensureKeyboardEnabled()` (UITestSupport.swift) first, unconditionally — this is what
    /// makes every caller (test07–test10) self-sufficient regardless of whether test01 ran, or ran
    /// first, or passed. That call's idempotent fast path (NumPad already enabled) is cheap and
    /// alert-free, so paying for it on every call costs little.
    @discardableResult
    private func measureKeyboardHeight(preset: String, pro: Bool,
                                       screenshotName: String) throws -> CGFloat {
        guard ensureKeyboardEnabled() else { return 0 } // failure already reported with a clear message

        let app = launchNumPad(debugRoutes: [
            "entitle?pro=\(pro ? 1 : 0)", "preset?value=\(preset)", "typing",
        ])
        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 20), "debug typing surface never appeared")

        if !waitForAnyKeyboard(app, timeout: 6) {
            field.tap() // becomeFirstResponder should have raised it; tap as a fallback
            XCTAssertTrue(waitForAnyKeyboard(app, timeout: 10),
                          "no keyboard appeared (hardware-keyboard setting on this sim?)")
        }
        XCTAssertTrue(switchToNumPadKeyboard(app),
                      "could not switch the active keyboard to NumPad (ensureKeyboardEnabled just " +
                      "confirmed it's enabled — this means the switcher UI itself misbehaved)")
        Thread.sleep(forTimeInterval: 1.5) // let the height constraint/animation settle

        // Measure the HOST-side `inputView` container, not the extension's own views: remote
        // (extension-process) elements report frames in their own window space, while `inputView`
        // (owned by the host app) is in screen coordinates. Its height = keyboard content + a
        // constant system band (input-assistant area), so it preserves the strict ordering the
        // matrix asserts. NumPad exposes no `.keyboard` element to measure (see above).
        let inputView = app.otherElements["inputView"].firstMatch
        XCTAssertTrue(inputView.waitForExistence(timeout: 5), "host inputView container missing")
        let height = inputView.frame.height
        XCTAssertGreaterThan(height, 0, "keyboard frame height should be positive")
        attachScreenshot(named: screenshotName)
        NSLog("[E2EMatrix] preset=\(preset) measured inputView height=\(height)")
        return height
    }
}
