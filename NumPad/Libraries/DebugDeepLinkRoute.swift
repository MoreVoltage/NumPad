//
//  DebugDeepLinkRoute.swift
//  NumPad
//
//  DEBUG-only deep-link routes (`numpad://debug/...`) that let the iOS Simulator be driven end to
//  end — via `simctl openurl` + `simctl io screenshot` — without a UI tap driver. Parsing is a pure
//  function (URL -> route enum) with no UIKit/AppDelegate dependency, so it's unit-testable in
//  isolation; `ViewController` is the only thing that actually executes a parsed route. Every route
//  and this entire file are DEBUG-only — zero release-build surface.
//

#if DEBUG
import Foundation

enum DebugDeepLinkRoute: Equatable {
    /// `numpad://debug/entitle?pro=1|0` — sets `Monetization.debugProOverride` (the same DEBUG
    /// simulated-Pro entitlement the Store screen's "Simulate Pro Entitlement" toggle uses).
    case entitlePro(Bool)
    /// `numpad://debug/preset?value=small|regular|tall|kiosk` — sets `KeyboardHeightPreset.selected`.
    case heightPreset(KeyboardHeightPreset)
    /// `numpad://debug/height` — pushes `KeyboardHeightViewController`.
    case heightScreen
    /// `numpad://debug/editor` — pushes the Custom Keyboard editor.
    case customKeyboardEditor
    /// `numpad://debug/typing` — presents a minimal text-field host to raise the keyboard extension.
    case typingSurface
    /// `numpad://debug/guide` — pushes `FeaturesGuideViewController`.
    case featuresGuide
    /// `numpad://debug/fullkeyboard?enabled=1|0` — sets the local `FeatureFlags.fullKeyboardEnabled`
    /// rollout flag (app group, so the keyboard extension's QWERTY page gate sees it immediately).
    case fullKeyboard(Bool)

    /// Parses a `numpad://debug/...` URL into a route. Returns `nil` for any URL whose host isn't
    /// `"debug"`, whose path isn't recognized, or whose required query item is missing/invalid — so
    /// callers can safely no-op rather than routing anywhere.
    static func parse(_ url: URL) -> DebugDeepLinkRoute? {
        guard url.host == "debug" else { return nil }
        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
        func queryValue(_ name: String) -> String? {
            queryItems?.first { $0.name == name }?.value
        }
        switch url.path {
        case "/entitle":
            switch queryValue("pro") {
            case "1": return .entitlePro(true)
            case "0": return .entitlePro(false)
            default: return nil
            }
        case "/preset":
            guard
                let raw = queryValue("value"),
                let preset = KeyboardHeightPreset(rawValue: raw)
            else { return nil }
            return .heightPreset(preset)
        case "/height":
            return .heightScreen
        case "/editor":
            return .customKeyboardEditor
        case "/typing":
            return .typingSurface
        case "/guide":
            return .featuresGuide
        case "/fullkeyboard":
            switch queryValue("enabled") {
            case "1": return .fullKeyboard(true)
            case "0": return .fullKeyboard(false)
            default: return nil
            }
        default:
            return nil
        }
    }

    /// Parses every `-debugRoute <value>` pair out of `arguments` (e.g. process launch arguments)
    /// into the same route enum `parse(_:)` produces from a `numpad://debug/...` URL — lets
    /// XCUITest drive DEBUG routing via `XCUIApplication().launch(launchArguments:)` with no URL at
    /// all. That matters because `simctl openurl` (and therefore any URL-based driver) shows an
    /// undismissable "Open in NumPad?" confirmation dialog under XCUITest on this runtime, and
    /// `XCUIApplication().launch()` needs no URL to begin with. Each `-debugRoute` value is treated
    /// as the path+query of a `numpad://debug/...` URL would be (e.g. `"preset?value=kiosk"`,
    /// `"entitle?pro=1"`, or a bare path like `"typing"`), so it's re-parsed with the exact same
    /// rules. Multiple pairs may appear in one launch and are returned in order, letting a single
    /// launch combine routes (e.g. entitle Pro, then select the Kiosk preset, then raise the typing
    /// surface). Malformed or unrecognized pairs are skipped rather than aborting the whole parse.
    static func parseAll(fromLaunchArguments arguments: [String]) -> [DebugDeepLinkRoute] {
        var routes: [DebugDeepLinkRoute] = []
        var index = 0
        while index < arguments.count {
            guard arguments[index] == "-debugRoute", index + 1 < arguments.count else {
                index += 1
                continue
            }
            if let url = URL(string: "numpad://debug/\(arguments[index + 1])"), let route = parse(url) {
                routes.append(route)
            }
            index += 2
        }
        return routes
    }

    /// `-skipOnboarding` launch argument: tells `ViewController` to bypass the interactive first-run
    /// onboarding flow (and the upsell triggers that key off it) so XCUITest reaches Home/Store/etc.
    /// on a fresh install deterministically, without stepping through WOW/ENABLE/TRY IT or racing a
    /// delayed upsell modal.
    static var shouldSkipOnboarding: Bool {
        ProcessInfo.processInfo.arguments.contains("-skipOnboarding")
    }
}
#endif
