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
        default:
            return nil
        }
    }
}
#endif
