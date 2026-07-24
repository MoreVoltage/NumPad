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

/// Reference-backed pending state so a modal-dismissal callback can retry the same request without
/// retaining the app delegate or relying on another lifecycle event.
final class PendingDeepLinkRequest {
    var url: URL?

    init(url: URL? = nil) {
        self.url = url
    }
}

/// Observes removal from the presentation window without taking over
/// `UIPresentationController.delegate`, which may already belong to the presented feature.
private final class PresentationDismissalSentinel: UIView {
    private var callbacks: [ObjectIdentifier: () -> Void] = [:]
    private var hasEnteredWindow = false

    init() {
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        accessibilityElementsHidden = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func observe(
        request: PendingDeepLinkRequest,
        callback: @escaping () -> Void
    ) {
        callbacks[ObjectIdentifier(request)] = callback
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            hasEnteredWindow = true
            return
        }
        guard hasEnteredWindow, !callbacks.isEmpty else { return }
        hasEnteredWindow = false
        let pendingCallbacks = Array(callbacks.values)
        callbacks.removeAll()
        // UIKit clears `presentedViewController` at the end of the dismissal transaction. Retry on
        // the next main-loop turn so route resolution sees the newly visible hierarchy.
        DispatchQueue.main.async {
            pendingCallbacks.forEach { $0() }
        }
    }
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

    /// Drains the app's pending request if present and presents the matching route.
    @discardableResult
    static func drainPending(from host: UIViewController) -> Bool {
        guard
            let appDelegate = UIApplication.shared.delegate as? AppDelegate,
            appDelegate.pendingDeepLinkRequest.url != nil
        else { return false }
        return drainPending(appDelegate.pendingDeepLinkRequest, from: host)
    }

    /// A valid route is consumed only after visible presentation succeeds. When an arbitrary
    /// standalone presentation blocks navigation, a delegate-free view sentinel retries this same
    /// request automatically after the blocking controller leaves its window.
    @discardableResult
    static func drainPending(
        _ request: PendingDeepLinkRequest,
        from host: UIViewController
    ) -> Bool {
        guard let url = request.url else { return false }
        guard let route = parse(url) else { return false }
        guard present(route, from: host) else {
            observeBlockingPresentationDismissal(
                from: host,
                request: request
            )
            return false
        }
        request.url = nil
        return true
    }

    // MARK: - Navigation helpers

    /// The navigation controller that should receive pushes: detail on iPad split, otherwise
    /// the host's own nav stack (or an embedded child's).
    static func activeNavigationController(from host: UIViewController) -> UINavigationController? {
        var visited = Set<ObjectIdentifier>()
        if let presented = presentedController(inHierarchyOf: host) {
            // Only explicit navigation containers are routeable. System controllers such as
            // alerts and share sheets may have private navigation children, but pushing into those
            // implementation details would hide or corrupt the route.
            guard isRouteablePresentedContainer(presented) else { return nil }
            return activeNavigationController(from: presented, visited: &visited)
        }
        return activeNavigationController(from: host, visited: &visited)
    }

    static func isRouteablePresentedContainer(_ controller: UIViewController) -> Bool {
        controller is UINavigationController
            || controller is UISplitViewController
            || controller is UITabBarController
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
        guard presentedController(inHierarchyOf: host) == nil else { return false }
        host.show(controller, sender: host)
        return true
    }

    /// Finds the topmost actual presentation anywhere under the host's containment root. Searching
    /// the whole hierarchy is required when an arbitrary child (not the lifecycle host itself)
    /// owns the modal.
    private static func presentedController(
        inHierarchyOf host: UIViewController
    ) -> UIViewController? {
        var root = host
        while let parent = root.parent {
            root = parent
        }
        var visited = Set<ObjectIdentifier>()
        return presentedController(in: root, visited: &visited)
    }

    private static func presentedController(
        in host: UIViewController,
        visited: inout Set<ObjectIdentifier>
    ) -> UIViewController? {
        let identity = ObjectIdentifier(host)
        guard visited.insert(identity).inserted else { return nil }

        if let presented = host.presentedViewController {
            return presentedController(in: presented, visited: &visited) ?? presented
        }

        let preferredChildren: [UIViewController]
        if let navigation = host as? UINavigationController {
            preferredChildren = navigation.visibleViewController.map { [$0] } ?? []
        } else if let split = host as? UISplitViewController {
            preferredChildren = Array(split.viewControllers.reversed())
        } else if let tabs = host as? UITabBarController {
            preferredChildren = tabs.selectedViewController.map { [$0] } ?? []
        } else {
            preferredChildren = Array(host.children.reversed())
        }

        for child in preferredChildren {
            if let presented = presentedController(in: child, visited: &visited) {
                return presented
            }
        }
        return nil
    }

    private static func observeBlockingPresentationDismissal(
        from host: UIViewController,
        request: PendingDeepLinkRequest
    ) {
        guard let blocking = presentedController(inHierarchyOf: host) else { return }
        let sentinel: PresentationDismissalSentinel
        if let existing = blocking.view.subviews
            .compactMap({ $0 as? PresentationDismissalSentinel })
            .first {
            sentinel = existing
        } else {
            sentinel = PresentationDismissalSentinel()
            blocking.view.addSubview(sentinel)
        }
        sentinel.observe(request: request) { [weak host, weak request] in
            guard let host, let request else { return }
            _ = drainPending(request, from: host)
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
            guard presentedController(inHierarchyOf: host) == nil else { return false }
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

    /// DEBUG-only deterministic test isolation. It clears app-owned values and resets content-free
    /// counters through their stable cross-process lock, then notifies any already-loaded app or
    /// keyboard UI. System keyboard enablement is owned by iOS Settings and is intentionally not
    /// affected.
    static func applyUITestAppGroupReset(
        defaults: UserDefaults = .group,
        typingQualityStore: TypingQualityCounterStore = .appGroup,
        postSettingsSync: () -> Void = { SettingsSync.post() }
    ) {
        for key in defaults.dictionaryRepresentation().keys {
            defaults.removeObject(forKey: key)
        }
        defaults.synchronize()
        typingQualityStore.resetForUITesting()
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
