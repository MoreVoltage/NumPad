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
        guard XCUIScreen.main.screenshot().image.size.width >= 700 else {
            throw XCTSkip("Kiosk height-picker entitlement coverage is iPad-only")
        }
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
        guard XCUIScreen.main.screenshot().image.size.width >= 700 else {
            throw XCTSkip("Kiosk is an iPad-only height preset; iPhone intentionally mirrors Tall")
        }
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

    // MARK: - test11: production iPad placement matrix

    func test11_adaptiveIPadKeyboardGeometryMatrix() throws {
        guard XCUIScreen.main.screenshot().image.size.width >= 700 else {
            throw XCTSkip("adaptive placement matrix is iPad-only")
        }
        guard ensureKeyboardEnabled() else { return }
        let customColumnLabel = try prepareCustomSideColumn()

        let automaticNumpad = try launchGeometryKeyboard(
            routes: ["numpadplacement?mode=automatic"],
            switchToQwerty: false
        )
        let automaticNumpadFrame = try unionFrame(
            labels: ["Letters", "1", "2", "3", "0", "Delete", "Enter"],
            in: automaticNumpad
        )
        let screenWidth = XCUIScreen.main.screenshot().image.size.width
        XCTAssertGreaterThan(automaticNumpadFrame.minX, 150)
        XCTAssertLessThan(automaticNumpadFrame.maxX, screenWidth - 150)
        try assertCustomSideColumn(
            labeled: customColumnLabel,
            staysInside: automaticNumpadFrame,
            in: automaticNumpad,
            placement: "automatic"
        )
        attachScreenshot(named: "11a-numpad-automatic")
        automaticNumpad.terminate()

        let leftNumpad = try launchGeometryKeyboard(
            routes: ["numpadplacement?mode=left"],
            switchToQwerty: false
        )
        let leftNumpadFrame = try unionFrame(
            labels: ["Letters", "1", "2", "3", "0", "Delete", "Enter"],
            in: leftNumpad
        )
        XCTAssertLessThan(leftNumpadFrame.minX, 20)
        XCTAssertLessThan(leftNumpadFrame.maxX, screenWidth * 0.65)
        try assertCustomSideColumn(
            labeled: customColumnLabel,
            staysInside: leftNumpadFrame,
            in: leftNumpad,
            placement: "left"
        )
        attachScreenshot(named: "11b-numpad-left")
        leftNumpad.terminate()

        let rightNumpad = try launchGeometryKeyboard(
            routes: ["numpadplacement?mode=right"],
            switchToQwerty: false
        )
        let rightNumpadFrame = try unionFrame(
            labels: ["Letters", "1", "2", "3", "0", "Delete", "Enter"],
            in: rightNumpad
        )
        XCTAssertGreaterThan(rightNumpadFrame.minX, screenWidth * 0.35)
        XCTAssertGreaterThan(rightNumpadFrame.maxX, screenWidth - 20)
        try assertCustomSideColumn(
            labeled: customColumnLabel,
            staysInside: rightNumpadFrame,
            in: rightNumpad,
            placement: "right"
        )
        attachScreenshot(named: "11c-numpad-right")
        rightNumpad.terminate()

        let centeredNumpad = try launchGeometryKeyboard(
            routes: ["numpadplacement?mode=center"],
            switchToQwerty: false
        )
        let centeredNumpadFrame = try unionFrame(
            labels: ["Letters", "1", "2", "3", "0", "Delete", "Enter"],
            in: centeredNumpad
        )
        XCTAssertGreaterThan(centeredNumpadFrame.minX, 150)
        XCTAssertLessThan(centeredNumpadFrame.maxX,
                          XCUIScreen.main.screenshot().image.size.width - 150)
        XCTAssertEqual(centeredNumpadFrame.minX, automaticNumpadFrame.minX, accuracy: 2)
        XCTAssertEqual(centeredNumpadFrame.maxX, automaticNumpadFrame.maxX, accuracy: 2)
        try assertCustomSideColumn(
            labeled: customColumnLabel,
            staysInside: centeredNumpadFrame,
            in: centeredNumpad,
            placement: "center"
        )
        attachScreenshot(named: "11d-numpad-centered")
        centeredNumpad.terminate()

        let fullNumpad = try launchGeometryKeyboard(
            routes: ["numpadplacement?mode=fullWidth"],
            switchToQwerty: false
        )
        let fullNumpadFrame = try unionFrame(
            labels: ["Letters", "1", "2", "3", "0", "Delete", "Enter"],
            in: fullNumpad
        )
        XCTAssertGreaterThan(fullNumpadFrame.width, centeredNumpadFrame.width + 200)
        XCTAssertLessThan(fullNumpadFrame.minX, 20)
        XCTAssertGreaterThan(fullNumpadFrame.maxX, screenWidth - 20)
        try assertCustomSideColumn(
            labeled: customColumnLabel,
            staysInside: fullNumpadFrame,
            in: fullNumpad,
            placement: "fullWidth"
        )
        attachScreenshot(named: "11e-numpad-full-width")
        fullNumpad.terminate()

        for (mode, screenshot) in [
            ("centered", "11f-qwerty-centered"),
            ("split", "11g-qwerty-split"),
            ("compactLeft", "11h-qwerty-compact-left"),
            ("compactRight", "11i-qwerty-compact-right"),
        ] {
            let app = try launchGeometryKeyboard(
                routes: ["qwertylayout?mode=\(mode)"],
                switchToQwerty: true
            )
            let lettersFrame = try unionFrame(
                labels: ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"],
                in: app
            )
            switch mode {
            case "centered":
                XCTAssertGreaterThan(lettersFrame.minX, 100)
                XCTAssertLessThan(lettersFrame.maxX, screenWidth - 100)
            case "split":
                let t = try firstButton(labeled: "T", in: app)
                let y = try firstButton(labeled: "Y", in: app)
                XCTAssertGreaterThanOrEqual(y.frame.minX - t.frame.maxX, 90)
            case "compactLeft":
                XCTAssertLessThan(lettersFrame.maxX, screenWidth * 0.55)
            case "compactRight":
                XCTAssertGreaterThan(lettersFrame.minX, screenWidth * 0.45)
            default:
                break
            }
            attachScreenshot(named: screenshot)
            app.terminate()
        }
    }

    // MARK: - Helpers
    //
    // `tapRow`, `navigateToKeyboardsList`, `ensureKeyboardEnabled`, and the active-keyboard
    // detection/switching helpers (`isNumPadKeyboardActive`, `isAnyKeyboardVisible`,
    // `waitForAnyKeyboard`, `switchToNumPadKeyboard`) all live in UITestSupport.swift — shared with
    // test01 and every keyboard-dependent test below, and with ScreenshotCaptureTests.

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

    private func launchGeometryKeyboard(routes: [String],
                                        switchToQwerty: Bool) throws -> XCUIApplication {
        let app = launchNumPad(
            // test11 writes its deterministic custom side column before entering the placement
            // matrix. Every matrix launch must preserve that same fixture while changing only the
            // placement route under test.
            resetAppGroup: false,
            debugRoutes: ["entitle?pro=1", "fullkeyboard?enabled=1"] + routes + ["typing"]
        )
        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 20))
        if !waitForAnyKeyboard(app, timeout: 6) {
            field.tap()
            XCTAssertTrue(waitForAnyKeyboard(app, timeout: 10))
        }
        let numPadPageKey = app.buttons["NumPad"].firstMatch
        let qwertyAlreadyActive = numPadPageKey.waitForExistence(timeout: 1)
        if switchToQwerty, !qwertyAlreadyActive {
            XCTAssertTrue(switchToNumPadKeyboard(app))
            let letters = app.buttons["Letters"].firstMatch
            XCTAssertTrue(letters.waitForExistence(timeout: 5), "ABC/Letters page key missing")
            letters.tap()
            _ = try firstButton(labeled: "Q", in: app)
        } else if !switchToQwerty, qwertyAlreadyActive {
            numPadPageKey.tap()
            XCTAssertTrue(app.buttons["1"].firstMatch.waitForExistence(timeout: 5))
        } else if !qwertyAlreadyActive {
            XCTAssertTrue(switchToNumPadKeyboard(app))
        }
        Thread.sleep(forTimeInterval: 0.8)
        return app
    }

    /// Persists one deterministic Column 1 key through the real editor UI. The editor's fresh
    /// in-memory seed is intentionally not written until the user edits, so the geometry test
    /// cannot merely assume another ordered E2E test happened to leave a custom keyboard behind.
    private func prepareCustomSideColumn() throws -> String {
        let app = launchNumPad(debugRoutes: ["entitle?pro=1", "editor"])
        let keyLibraryHeader = app.staticTexts["Key Library"]
        XCTAssertTrue(
            keyLibraryHeader.waitForExistence(timeout: 20),
            "custom-keyboard editor did not expose the key library"
        )

        var column1 = app.buttons["Column 1"].firstMatch
        XCTAssertTrue(column1.waitForExistence(timeout: 5), "Column 1 toggle missing")
        if !column1.isSelected {
            column1.tap()
            column1 = app.buttons["Column 1"].firstMatch
            XCTAssertTrue(column1.isSelected, "Column 1 did not enable")
        }

        // Fresh editor state seeds Column 1 from the three legacy side keys, and the preview
        // precedes the Key Library in accessibility order. A persisted custom config may instead
        // expose an empty slot, so retain that as the fallback after enabling Column 1 above.
        let seededLabel = [",", ".", "Space"].first {
            app.cells.matching(NSPredicate(format: "label == %@", $0)).count > 1
        }
        let columnSlot = seededLabel.map {
            app.cells.matching(NSPredicate(format: "label == %@", $0)).firstMatch
        } ?? app.cells.matching(NSPredicate(format: "label == 'Empty slot'")).firstMatch
        XCTAssertTrue(columnSlot.exists, "no editable Column 1 slot resolved")
        columnSlot.tap()

        let chipLabel = try XCTUnwrap(
            ["€", "#", "(", ")", "$", "%"].first {
                app.cells.matching(NSPredicate(format: "label == %@", $0)).count == 1
            },
            "no unassigned key-library chip was available"
        )
        app.cells.matching(NSPredicate(format: "label == %@", chipLabel)).firstMatch.tap()
        XCTAssertGreaterThan(
            app.cells.matching(NSPredicate(format: "label == %@", chipLabel)).count,
            1,
            "selected Column 1 slot did not persist the test chip"
        )
        app.terminate()
        return chipLabel
    }

    private func assertCustomSideColumn(labeled label: String,
                                        staysInside contentFrame: CGRect,
                                        in app: XCUIApplication,
                                        placement: String) throws {
        let customFrame = try firstButton(labeled: label, in: app).frame
        let digitsFrame = try unionFrame(
            labels: ["1", "2", "3", "4", "5", "6", "7", "8", "9"],
            in: app
        )
        XCTAssertGreaterThanOrEqual(
            customFrame.minX,
            contentFrame.minX - 2,
            "\(placement) custom side column escaped the leading content boundary"
        )
        XCTAssertLessThanOrEqual(
            customFrame.maxX,
            contentFrame.maxX + 2,
            "\(placement) custom side column escaped the trailing content boundary"
        )
        XCTAssertTrue(
            customFrame.maxX <= digitsFrame.minX + 2
                || customFrame.minX >= digitsFrame.maxX - 2,
            "\(placement) custom side column overlapped the fixed digit grid"
        )
    }

    private func firstButton(labeled label: String,
                             in app: XCUIApplication) throws -> XCUIElement {
        let upper = app.buttons[label].firstMatch
        if upper.waitForExistence(timeout: 5) { return upper }
        let lower = app.buttons[label.lowercased()].firstMatch
        guard lower.waitForExistence(timeout: 2) else {
            XCTFail("keyboard button '\(label)' missing")
            throw NSError(domain: "E2EMatrixTests", code: 1)
        }
        return lower
    }

    private func unionFrame(labels: [String], in app: XCUIApplication) throws -> CGRect {
        let frames = try labels.map { try firstButton(labeled: $0, in: app).frame }
        return frames.dropFirst().reduce(frames[0]) { $0.union($1) }
    }
}
