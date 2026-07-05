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
}
