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
    case profileDocument(URL)
    #if DEBUG
    case debug(DebugDeepLinkRoute)
    #endif
}

enum DeepLinkRouter {
    /// Parses a `numpad://` URL into a typed route. Returns nil for unrecognized hosts.
    static func parse(_ url: URL) -> DeepLinkRoute? {
        if url.isFileURL {
            return url.pathExtension.lowercased() == "numpadprofile"
                ? .profileDocument(url)
                : nil
        }
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
        case .profileDocument(let url):
            push(ProfilesViewController(importURL: url), from: host)
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
        var visited = Set<ObjectIdentifier>()
        return activeNavigationController(from: host, visited: &visited)
    }

    private static func activeNavigationController(
        from host: UIViewController,
        visited: inout Set<ObjectIdentifier>
    ) -> UINavigationController? {
        let identity = ObjectIdentifier(host)
        guard visited.insert(identity).inserted else { return nil }

        if let presented = host.presentedViewController,
           let navigation = activeNavigationController(from: presented, visited: &visited) {
            return navigation
        }

        if let split = host as? UISplitViewController {
            let secondary = split.viewController(for: .secondary)
                ?? split.viewControllers.last
            if let secondary,
               let navigation = activeNavigationController(from: secondary, visited: &visited) {
                return navigation
            }
        }

        if let navigation = host as? UINavigationController {
            if let visible = navigation.visibleViewController,
               visible !== navigation,
               let nested = activeNavigationController(from: visible, visited: &visited) {
                return nested
            }
            return navigation
        }

        if let tabs = host as? UITabBarController,
           let selected = tabs.selectedViewController,
           let navigation = activeNavigationController(from: selected, visited: &visited) {
            return navigation
        }

        for child in host.children.reversed() {
            if let navigation = activeNavigationController(from: child, visited: &visited) {
                return navigation
            }
        }

        return host.navigationController
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

    /// DEBUG-only deterministic test isolation. It clears the shared defaults domain that persists
    /// across app reinstalls on some simulator runtimes, then notifies any already-loaded app or
    /// keyboard UI. System keyboard enablement is owned by iOS Settings and is intentionally not
    /// affected.
    static func applyUITestAppGroupReset(
        defaults: UserDefaults = .group,
        postSettingsSync: () -> Void = { SettingsSync.post() }
    ) {
        for key in defaults.dictionaryRepresentation().keys {
            defaults.removeObject(forKey: key)
        }
        defaults.synchronize()
        postSettingsSync()
        NotificationCenter.default.post(name: .keyboardProfileDidChange, object: nil)
    }

    /// Runs before migration, StoreKit, managed configuration, or Cloud Sync when the UI-test
    /// harness explicitly requests isolation. Keeping this as a launch argument (rather than a
    /// post-launch route) prevents startup work from racing stale app-group values back into the
    /// test after reset.
    @discardableResult
    static func applyUITestAppGroupResetIfRequested(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        defaults: UserDefaults = .group,
        postSettingsSync: () -> Void = { SettingsSync.post() }
    ) -> Bool {
        guard arguments.contains("-resetUITestAppGroup") else { return false }
        applyUITestAppGroupReset(
            defaults: defaults,
            postSettingsSync: postSettingsSync
        )
        return true
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
