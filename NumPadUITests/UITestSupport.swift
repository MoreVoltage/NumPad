//
//  UITestSupport.swift
//  NumPadUITests
//
//  Shared helpers for the NumPadUITests harness. This target drives the NumPad app (and, for the
//  Settings-keyboard-enablement test, Settings.app itself) purely through the accessibility tree —
//  no `simctl openurl` (which shows an undismissable "Open in NumPad?" confirmation dialog under
//  XCUITest on this runtime) and no defaults-write tricks (which don't enable third-party keyboards
//  on this simulator runtime). Every test attaches its own screenshots with `.keepAlways` so a full
//  visual record survives even a green run — the whole point of this harness is the record, not
//  just the pass/fail signal.
//

import XCTest

extension XCTestCase {
    /// Launches a fresh `XCUIApplication` for the NumPad app target with DEBUG launch-argument
    /// routing (see `DebugDeepLinkRoute.parseAll(fromLaunchArguments:)` in the app target). Defaults
    /// to `-skipOnboarding` so screenshots land on a deterministic screen instead of racing the
    /// interactive first-run flow; pass `skipOnboarding: false` for a test that wants onboarding.
    /// `debugRoutes` are applied in order (e.g. `["entitle?pro=1", "preset?value=kiosk", "typing"]`).
    @discardableResult
    func launchNumPad(skipOnboarding: Bool = true, debugRoutes: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        var arguments: [String] = []
        if skipOnboarding {
            arguments.append("-skipOnboarding")
        }
        for route in debugRoutes {
            arguments.append("-debugRoute")
            arguments.append(route)
        }
        app.launchArguments = arguments
        app.launch()
        return app
    }

    /// Captures a full-screen screenshot and attaches it with `.keepAlways` so it's exported by
    /// `xcresulttool` regardless of whether the test passes or fails.
    func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Waits up to `timeout` for `element` to exist, returning whether it appeared. Use for
    /// steps that should degrade gracefully (e.g. an OS alert that may or may not show) rather than
    /// hard-failing the whole test over a single flaky step.
    @discardableResult
    func waitForExistence(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        element.waitForExistence(timeout: timeout)
    }

    /// Taps the first hittable row/static-text with `label` in `app`, scrolling up to a few screens
    /// to find it. Returns `false` (without asserting) if the row never appears or never becomes
    /// hittable — callers decide how to surface that, since some callers (e.g.
    /// `ensureKeyboardEnabled`) want their own specific failure message rather than a generic one
    /// from this shared helper.
    @discardableResult
    func tapRow(in app: XCUIApplication, labeled label: String, timeout: TimeInterval = 10) -> Bool {
        let element = app.staticTexts[label].firstMatch
        guard element.waitForExistence(timeout: timeout) else { return false }
        var swipes = 0
        while !element.isHittable && swipes < 4 {
            app.swipeUp()
            swipes += 1
        }
        guard element.isHittable else { return false }
        element.tap()
        return true
    }

    /// Navigates `settings` (a launched `com.apple.Preferences` app) to General > Keyboard >
    /// Keyboards. Returns `false` without asserting if the path can't be walked — callers
    /// decide how to fail.
    ///
    /// Retries from a fresh Settings launch: the first tap after a launch can be silently
    /// swallowed while the root list is still settling (observed: "General" reported tapped,
    /// yet the failure-time hierarchy still showed the root page), and a relaunch also resets
    /// whatever page Settings' state restoration brought back.
    @discardableResult
    func navigateToKeyboardsList(in settings: XCUIApplication) -> Bool {
        for attempt in 0..<3 {
            if attempt > 0 {
                settings.terminate()
                settings.launch()
            }
            if navigateToKeyboardsListOnce(in: settings) { return true }
        }
        return false
    }

    private func navigateToKeyboardsListOnce(in settings: XCUIApplication) -> Bool {
        guard tapRow(in: settings, labeled: "General") else { return false }
        guard tapRow(in: settings, labeled: "Keyboard") else { return false }
        // The keyboards LIST row can't be tapped by its "Keyboards" label: on this runtime the
        // Keyboard page's own nav-bar title is also "Keyboards", and `staticTexts.firstMatch`
        // resolves to the title (a no-op tap). The row cell carries the stable accessibility
        // identifier `KEYBOARDS` (label "Keyboards, <count>"), so target that instead.
        let keyboardsList = settings.cells.matching(
            NSPredicate(format: "identifier == 'KEYBOARDS' OR label BEGINSWITH 'Keyboards,'")).firstMatch
        guard keyboardsList.waitForExistence(timeout: 10) else { return false }
        keyboardsList.tap()
        return true
    }

    /// Drives Settings.app to guarantee the NumPad keyboard is enabled in the system Keyboards
    /// list, then returns. Idempotent: if NumPad already appears in the list, this returns
    /// immediately without touching any other UI (no Full Access dance, no alerts) — that fast
    /// path must stay cheap and alert-free since every keyboard-dependent test calls this at its
    /// top, regardless of whether test01 ran first or ran at all. XCTest's alphabetical run order
    /// is not a dependency contract: a single flaky step earlier in the suite must not cascade into
    /// every later height measurement failing with an unrelated "could not switch keyboard"
    /// message.
    ///
    /// Fails fast via `XCTFail` with a specific message at whichever step didn't resolve, so
    /// callers can just do `guard ensureKeyboardEnabled() else { return }`.
    @discardableResult
    func ensureKeyboardEnabled() -> Bool {
        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        settings.launch()
        defer { settings.terminate() }

        guard navigateToKeyboardsList(in: settings) else {
            XCTFail("ensureKeyboardEnabled: could not reach Settings > General > Keyboard > Keyboards")
            return false
        }

        // Idempotency: a row containing "NumPad" in the Keyboards list means it's already enabled.
        // ("Add New Keyboard…" doesn't contain "NumPad", so the predicate can't false-positive —
        // but "NumPad Type — NumPad" would, so the sibling QWERTY keyboard is excluded.)
        let numpadPredicate = NSPredicate(
            format: "label CONTAINS 'NumPad' AND NOT (label CONTAINS 'NumPad Type')")
        let existingRow = settings.cells.matching(numpadPredicate).firstMatch
        if existingRow.waitForExistence(timeout: 3) {
            return true // already enabled — nothing else to do
        }

        // Element type varies by runtime (cell vs button inside a cell) — match any type.
        let addNew = settings.descendants(matching: .any).matching(
            NSPredicate(format: "label BEGINSWITH 'Add New Keyboard'")).firstMatch
        guard addNew.waitForExistence(timeout: 5) else {
            XCTFail("ensureKeyboardEnabled: 'Add New Keyboard' row not found")
            return false
        }
        addNew.tap()

        // Third-party section lists the container app's display name; match loosely.
        let numpadEntry = settings.cells.matching(numpadPredicate).firstMatch
        guard numpadEntry.waitForExistence(timeout: 5) else {
            XCTFail("ensureKeyboardEnabled: NumPad not offered under Add New Keyboard (is the app installed?)")
            return false
        }
        numpadEntry.tap()

        // Some runtimes confirm with a nav-bar Done instead of adding directly.
        let done = settings.buttons["Done"]
        if done.waitForExistence(timeout: 2), done.isHittable {
            done.tap()
        }

        guard existingRow.waitForExistence(timeout: 5) else {
            XCTFail("ensureKeyboardEnabled: NumPad row did not appear in the Keyboards list after adding")
            return false
        }
        return true
    }

    // MARK: - Active-keyboard detection (shared by E2EMatrixTests and ScreenshotCaptureTests)
    //
    // Extracted here (rather than duplicated per test class) because both the height matrix and the
    // marketing screenshot capture need to force the system keyboard switcher over to NumPad before
    // driving anything keyboard-side.

    /// True when the frontmost keyboard is NumPad. IMPORTANT: on this runtime a custom keyboard
    /// extension exposes NO `XCUIElementType.keyboard` element at all — its keys are plain
    /// `.button`s from the extension process, merged into the host app's tree under anonymous
    /// `Other`s (verified via a failure-time hierarchy dump). So this must query app-wide for
    /// NumPad's own distinctive keys, never inside `app.keyboards` (which only ever matches the
    /// SYSTEM keyboard here).
    ///
    /// Do NOT key this off a "Next Keyboard" button: `KeyboardViewController.makeItems()` only emits
    /// that dedicated globe key when `needsInputModeSwitchKey` is true, which itself is true only on
    /// Home-button devices (see its doc comment: "iOS draws no system globe affordance" there) — on
    /// every modern simulator this repo targets (iPhone 17 Pro Max, iPad Pro M4/M5, etc.) that key
    /// never renders at all, so checking for it always returns false even while NumPad is genuinely
    /// active. "Delete" (capitalized) and "Enter" are unconditional on NumPad's bottom row and only
    /// coexist there — the system keyboard's equivalents are lowercase ("delete", "return").
    func isNumPadKeyboardActive(_ app: XCUIApplication) -> Bool {
        app.buttons["Delete"].exists && app.buttons["Enter"].exists
    }

    /// True when ANY keyboard is up: NumPad (no `.keyboard` element — see above), the system
    /// keyboard (`app.keyboards`), or the host-side `inputView` container that wraps whichever
    /// input view is showing.
    func isAnyKeyboardVisible(_ app: XCUIApplication) -> Bool {
        isNumPadKeyboardActive(app)
            || app.keyboards.firstMatch.exists
            || app.otherElements["inputView"].firstMatch.exists
    }

    /// Polls for `isAnyKeyboardVisible` — there is no single element to `waitForExistence` on,
    /// because the three signals live in different parts of the tree.
    @discardableResult
    func waitForAnyKeyboard(_ app: XCUIApplication, timeout: TimeInterval) -> Bool {
        let deadline = Date(timeIntervalSinceNow: timeout)
        while Date() < deadline {
            if isAnyKeyboardVisible(app) { return true }
            Thread.sleep(forTimeInterval: 0.5)
        }
        return isAnyKeyboardVisible(app)
    }

    /// Switches the active keyboard to NumPad by tapping the system "Next keyboard" control.
    ///
    /// IMPORTANT (confirmed via an accessibility-hierarchy dump on iOS 26.5): that control — `Button,
    /// label: 'Next keyboard', value: NumPad` — is NOT a descendant of the `Keyboard` typed element
    /// (which only contains the QWERTY key rows). It renders as a sibling accessory-row button
    /// overlaid near the bottom of the input view, so it must be looked up app-wide
    /// (`app.buttons[...]`), never scoped under `app.keyboards.firstMatch.buttons[...]` — the latter
    /// never finds it, no matter how long you wait. Its `value` already names the keyboard a tap
    /// switches to (there's no picker menu with only two keyboards installed on this runtime), so a
    /// plain tap is enough — no long-press needed.
    @discardableResult
    func switchToNumPadKeyboard(_ app: XCUIApplication) -> Bool {
        if isNumPadKeyboardActive(app) { return true }
        let keyboard = app.keyboards.firstMatch
        // iOS shows a one-time "Quickly Change Keyboards" tutorial ("Tap 🌐 to switch keyboards.
        // Touch and hold to select from a list." + a "Continue" button) the first time this
        // simulator ever encounters a multi-keyboard switch — confirmed by screenshot on a fresh
        // simulator instance. It visually overlaps the globe key and swallows taps aimed at it
        // until dismissed, which otherwise looks exactly like the tap silently doing nothing.
        let tutorialContinue = app.buttons["Continue"]
        if tutorialContinue.waitForExistence(timeout: 2) {
            tutorialContinue.tap()
        }
        for _ in 0..<5 {
            guard keyboard.waitForExistence(timeout: 5) else { break }
            // Re-query fresh every iteration (never reuse a resolved element across iterations): on
            // iPad the button's frame/identity can shift between when it's queried and when the tap
            // synthesizes (observed once landing on a now-relabeled "emoji" button instead), so a
            // stale reference from an earlier loop pass is exactly the kind of thing to avoid.
            let globe = app.buttons["Next keyboard"]
            guard globe.waitForExistence(timeout: 4) else { break }
            // Plain `.tap()` computes a hit point from the element's frame and was observed on iPad
            // to resolve to `{-1, -1}` (an invalid point outside the element, presumably because this
            // button's frame is reported oddly on that idiom) — silently tapping nothing. A
            // normalized-offset coordinate tap sidesteps XCUITest's own hit-point computation
            // entirely and reliably lands in the middle of whatever frame the element actually has.
            let center = globe.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            center.tap()
            Thread.sleep(forTimeInterval: 1.5)
            if isNumPadKeyboardActive(app) { return true }
        }
        return isNumPadKeyboardActive(app)
    }

    /// Launches on the debug typing surface, raises the keyboard, and forces the active keyboard to
    /// NumPad. Shared entry point for any screenshot/E2E test that needs to drive the extension's
    /// keys rather than just look at an app screen. Calls `ensureKeyboardEnabled()` first so callers
    /// are self-sufficient regardless of run order.
    ///
    /// Returns `nil` only when the typing surface itself never raised ANY keyboard (field never
    /// appeared, or neither NumPad nor the system keyboard showed up) — that's a real failure, worth
    /// an `XCTFail` at the call site. `numPadActive` on the returned tuple separately reports
    /// whether `switchToNumPadKeyboard` actually landed on NumPad; callers that only need a
    /// screenshot of *a* keyboard (not necessarily NumPad specifically) can check it themselves and
    /// degrade gracefully rather than failing outright, since the switch has been observed to
    /// intermittently fail on some simulator/idiom combinations for reasons external to this app.
    @discardableResult
    func launchNumPadOnTypingSurface(extraDebugRoutes: [String] = []) -> (app: XCUIApplication, field: XCUIElement, numPadActive: Bool)? {
        guard ensureKeyboardEnabled() else { return nil }
        let app = launchNumPad(debugRoutes: extraDebugRoutes + ["typing"])
        let field = app.textFields.firstMatch
        guard field.waitForExistence(timeout: 20) else { return nil }
        if !waitForAnyKeyboard(app, timeout: 6) {
            field.tap()
            guard waitForAnyKeyboard(app, timeout: 10) else { return nil }
        }
        let switched = switchToNumPadKeyboard(app)
        Thread.sleep(forTimeInterval: 1.0) // let the height/layout settle before interacting further
        return (app, field, switched)
    }
}
