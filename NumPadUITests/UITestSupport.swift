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
    /// Keyboards. Returns `false` without asserting if any row along the way doesn't appear —
    /// callers decide how to fail.
    @discardableResult
    func navigateToKeyboardsList(in settings: XCUIApplication) -> Bool {
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
        // ("Add New Keyboard…" doesn't contain "NumPad", so the predicate can't false-positive.)
        let numpadPredicate = NSPredicate(format: "label CONTAINS 'NumPad'")
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
}
