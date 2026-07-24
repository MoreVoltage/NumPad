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
    /// - Returns: `false` when a standalone presented controller blocks visible navigation.
    @discardableResult
    static func present(_ route: DeepLinkRoute, from host: UIViewController) -> Bool {
        switch route {
        case .storePreview(let source):
            let store = StoreViewController()
            store.source = source
            return push(store, from: host)
        case .profileDocument(let url):
            return push(ProfilesViewController(importURL: url), from: host)
        #if DEBUG
        case .debug(let debugRoute):
            return presentDebug(debugRoute, from: host)
        #endif
        }
    }

    /// Drains `AppDelegate.pendingURL` if present and presents the matching route.
    @discardableResult
    static func drainPending(from host: UIViewController) -> Bool {
        guard
            let appDelegate = UIApplication.shared.delegate as? AppDelegate,
            appDelegate.pendingURL != nil
        else { return false }
        return drainPending(&appDelegate.pendingURL, from: host)
    }

    /// Injectable pending-route seam. A valid route is consumed only after it is presented in the
    /// visible navigation context; standalone modals leave it queued for the presenter's next
    /// appearance.
    @discardableResult
    static func drainPending(
        _ pendingURL: inout URL?,
        from host: UIViewController
    ) -> Bool {
        guard let url = pendingURL else { return false }
        guard let route = parse(url) else { return false }
        guard present(route, from: host) else { return false }
        pendingURL = nil
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

        if let presented = host.presentedViewController {
            // Never fall through to a navigation stack hidden behind a standalone modal. A
            // presented navigation controller remains a valid, visible routing destination.
            return activeNavigationController(from: presented, visited: &visited)
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

    @discardableResult
    private static func push(
        _ controller: UIViewController,
        from host: UIViewController
    ) -> Bool {
        if let nav = activeNavigationController(from: host) {
            nav.pushViewController(controller, animated: true)
            return true
        }
        guard !containsPresentedController(in: host) else { return false }
        host.show(controller, sender: host)
        return true
    }

    private static func containsPresentedController(in host: UIViewController) -> Bool {
        var visited = Set<ObjectIdentifier>()
        return containsPresentedController(in: host, visited: &visited)
    }

    private static func containsPresentedController(
        in host: UIViewController,
        visited: inout Set<ObjectIdentifier>
    ) -> Bool {
        let identity = ObjectIdentifier(host)
        guard visited.insert(identity).inserted else { return false }
        if host.presentedViewController != nil { return true }
        return host.children.contains {
            containsPresentedController(in: $0, visited: &visited)
        }
    }

    #if DEBUG
    private static func presentDebug(
        _ route: DebugDeepLinkRoute,
        from host: UIViewController
    ) -> Bool {
        switch route {
        case .entitlePro(let isEntitled):
            Monetization.debugProOverride = isEntitled
            SettingsSync.post()
            return true
        case .heightPreset(let preset):
            KeyboardHeightPreset.selected = preset
            SettingsSync.post()
            return true
        case .heightScreen:
            return push(KeyboardHeightViewController(), from: host)
        case .customKeyboardEditor:
            return push(CustomKeyboardEditorViewController(), from: host)
        case .typingSurface:
            guard !containsPresentedController(in: host) else { return false }
            host.present(DebugTypingViewController(), animated: true)
            return true
        case .featuresGuide:
            return push(FeaturesGuideViewController(), from: host)
        case .fullKeyboard(let enabled):
            FeatureFlags.fullKeyboardEnabled = enabled
            SettingsSync.post()
            return true
        case .qwertyTestReset:
            applyQwertyTestReset()
            return true
        case .qwertyLayout(let mode):
            applyLayoutTestPreference(qwerty: mode)
            return true
        case .numpadPlacement(let placement):
            applyLayoutTestPreference(numpad: placement)
            return true
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

    /// DEBUG-only deterministic test isolation. It clears app-owned values and content-free
    /// counter artifacts in the shared container, then notifies any already-loaded app or keyboard
    /// UI. System keyboard enablement is owned by iOS Settings and is intentionally not affected.
    static func applyUITestAppGroupReset(
        defaults: UserDefaults = .group,
        artifactURLs: [URL]? = nil,
        postSettingsSync: () -> Void = { SettingsSync.post() }
    ) {
        for key in defaults.dictionaryRepresentation().keys {
            defaults.removeObject(forKey: key)
        }
        defaults.synchronize()
        for url in artifactURLs ?? uiTestAppGroupArtifactURLs {
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            try? FileManager.default.removeItem(at: url)
        }
        postSettingsSync()
        NotificationCenter.default.post(name: .keyboardProfileDidChange, object: nil)
    }

    private static var uiTestAppGroupArtifactURLs: [URL] {
        let counters = TypingQualityCounterStore.appGroup.fileURL
        return [counters, counters.appendingPathExtension("lock")]
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
