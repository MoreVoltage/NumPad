//
//  DeepLinkRouter.swift
//  NumPad
//
//  Shared deep-link presentation for iPhone and iPad. The window root always hosts
//  ViewController (lifecycle coordinator); this router finds the active navigation
//  context and presents destinations without depending on which shell is embedded.
//

import UIKit

enum DeepLinkRoute: Equatable {
    case storePreview(source: String)
    #if DEBUG
    case debug(DebugDeepLinkRoute)
    #endif
}

enum DeepLinkRouter {
    /// Parses a `numpad://` URL into a typed route. Returns nil for unrecognized hosts.
    static func parse(_ url: URL) -> DeepLinkRoute? {
        guard url.scheme == "numpad" else { return nil }
        if url.host == "store-preview" {
            let source = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first { $0.name == "source" }?.value
            return .storePreview(source: source ?? "deep_link")
        }
        #if DEBUG
        if let debug = DebugDeepLinkRoute.parse(url) {
            return .debug(debug)
        }
        #endif
        return nil
    }

    /// Presents `route` from the active navigation context under `host`.
    /// - Parameter host: The lifecycle coordinator (typically the window root `ViewController`).
    static func present(_ route: DeepLinkRoute, from host: UIViewController) {
        switch route {
        case .storePreview(let source):
            let store = StoreViewController()
            store.source = source
            push(store, from: host)
        #if DEBUG
        case .debug(let debugRoute):
            presentDebug(debugRoute, from: host)
        #endif
        }
    }

    /// Drains `AppDelegate.pendingURL` if present and presents the matching route.
    @discardableResult
    static func drainPending(from host: UIViewController) -> Bool {
        guard
            let appDelegate = UIApplication.shared.delegate as? AppDelegate,
            let url = appDelegate.pendingURL
        else { return false }
        appDelegate.pendingURL = nil
        guard let route = parse(url) else { return false }
        present(route, from: host)
        return true
    }

    // MARK: - Navigation helpers

    /// The navigation controller that should receive pushes: detail on iPad split, otherwise
    /// the host's own nav stack (or an embedded child's).
    static func activeNavigationController(from host: UIViewController) -> UINavigationController? {
        if let split = host.children.compactMap({ $0 as? UISplitViewController }).first
            ?? host as? UISplitViewController {
            if let secondary = split.viewController(for: .secondary) as? UINavigationController {
                return secondary
            }
            if let secondary = split.viewControllers.last as? UINavigationController {
                return secondary
            }
        }
        if let nav = host.navigationController { return nav }
        if let nav = host.children.compactMap({ $0 as? UINavigationController }).first { return nav }
        // Phone: Home is embedded; its navigationController is the InteractiveNavigationController
        // wrapping the storyboard root.
        if let home = host.children.compactMap({ $0 as? HomeViewController }).first {
            return home.navigationController
        }
        if let split = host.children.compactMap({ $0 as? IPadSettingsSplitViewController }).first {
            return split.viewController(for: .secondary) as? UINavigationController
                ?? split.viewControllers.last as? UINavigationController
        }
        return nil
    }

    private static func push(_ controller: UIViewController, from host: UIViewController) {
        if let nav = activeNavigationController(from: host) {
            nav.pushViewController(controller, animated: true)
            return
        }
        host.show(controller, sender: host)
    }

    #if DEBUG
    private static func presentDebug(_ route: DebugDeepLinkRoute, from host: UIViewController) {
        switch route {
        case .entitlePro(let isEntitled):
            Monetization.debugProOverride = isEntitled
            SettingsSync.post()
        case .heightPreset(let preset):
            KeyboardHeightPreset.selected = preset
            SettingsSync.post()
        case .heightScreen:
            push(KeyboardHeightViewController(), from: host)
        case .customKeyboardEditor:
            push(CustomKeyboardEditorViewController(), from: host)
        case .typingSurface:
            host.present(DebugTypingViewController(), animated: true)
        case .featuresGuide:
            push(FeaturesGuideViewController(), from: host)
        case .fullKeyboard(let enabled):
            FeatureFlags.fullKeyboardEnabled = enabled
            SettingsSync.post()
        case .qwertyTestReset:
            applyQwertyTestReset()
        case .qwertyLayout(let mode):
            applyLayoutTestPreference(qwerty: mode)
        case .numpadPlacement(let placement):
            applyLayoutTestPreference(numpad: placement)
        }
    }

    /// Narrow deterministic-state hook for QWERTY UI tests. DEBUG-only with the route itself:
    /// no release-build parser or mutation surface exists. One generation bump prevents a live
    /// Split View keyboard from writing its stale learned stores back after they are cleared.
    static func applyQwertyTestReset(
        postSettingsSync: () -> Void = { SettingsSync.post() }
    ) {
        QwertyTouchPersonalizationPersistence.resetAll()
        UserPrefs.qwertyAutocorrect = true
        UserPrefs.qwertySuggestions = true
        UserPrefs.qwertyDoubleSpacePeriod = false
        postSettingsSync()
    }

    /// Narrow DEBUG-only mutation seam for the iPad visual geometry matrix.
    static func applyLayoutTestPreference(
        qwerty: QwertyLayoutMode? = nil,
        numpad: NumpadPlacement? = nil,
        postSettingsSync: () -> Void = { SettingsSync.post() }
    ) {
        if let qwerty {
            UserPrefs.qwertyLayoutMode = qwerty
        }
        if let numpad {
            UserPrefs.numpadPlacement = numpad
        }
        postSettingsSync()
    }
    #endif
}
