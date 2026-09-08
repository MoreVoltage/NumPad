//
//  ViewController.swift
//  NumPad
//
//  Created by Lasha Efremidze on 2/19/17.
//  Copyright © 2017 MoreVoltage. All rights reserved.
//

import UIKit
import RevealingSplashView

class ViewController: UIViewController {
    private var deepLinkObserver: NSObjectProtocol?
    private var pendingDeepLinkObserver: NSObjectProtocol?
    private var deepLinkRetry: DispatchWorkItem?
    /// The first foreground is handled by `StoreManager.start()` (cold launch); only *subsequent*
    /// activations trigger a downgrade-capable entitlement refresh.
    private var hasBecomeActiveOnce = false
    /// True once the post-splash launch sequence has finished. Gates the foreground first-run-upsell
    /// retry so it can't race the splash/onboarding on the very first activation.
    private var launchFinished = false
    /// Bottom constraint of the demo field; its constant is adjusted to keep the field
    /// visible above the keyboard (any keyboard — NumPad or system, which differ in height).
    private var demoFieldBottomConstraint: NSLayoutConstraint?
    private let demoFieldBottomInset: CGFloat = 16

    lazy var splashView: RevealingSplashView = { [unowned self] in
        let image = #imageLiteral(resourceName: "hashtag")
        let view = RevealingSplashView(iconImage: image, iconInitialSize: image.size, backgroundColor: .primary)
        self.view.addSubview(view)
        return view
    }()

    lazy var tableView: HomeViewController = { [unowned self] in
        let viewController = HomeViewController.instantiate()
        self.add(viewController)
        viewController.view.edgesToSuperview()
        // Add a "Try Keyboard" demo input below the splash to let users experiment
        let demoField = UITextField()
        demoField.placeholder = NSLocalizedString("Try the NumPad keyboard here", comment: "Demo text field placeholder on the home screen")
        demoField.borderStyle = .roundedRect
        demoField.backgroundColor = .secondarySystemBackground
        self.view.addSubview(demoField)
        demoField.translatesAutoresizingMaskIntoConstraints = false
        let bottom = demoField.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor, constant: -demoFieldBottomInset)
        self.demoFieldBottomConstraint = bottom
        NSLayoutConstraint.activate([
            demoField.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 16),
            demoField.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -16),
            bottom,
            demoField.heightAnchor.constraint(equalToConstant: 44)
        ])
        // Add toolbar with a Done button to dismiss the keyboard in-app
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        let flex = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let done = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(dismissKeyboard))
        toolbar.items = [flex, done]
        demoField.inputAccessoryView = toolbar
        return viewController
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        interactiveNavigationBarHidden = true

        _ = tableView

        // Install the deep-link observer up front (not inside the splash completion) so a cold
        // launch via numpad:// — where didBecomeActive can fire before the splash finishes —
        // isn't missed. Also drain any URL already set during launch.
        let drainDeepLink: (Notification) -> Void = { [weak self] _ in
            self?.handlePendingDeepLink()
        }
        deepLinkObserver = NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            // Funnel analytics that must run on every foreground, independent of the launch and
            // paywall gates below: the keyboard lock-funnel counters the extension bumps (it has no
            // Firebase of its own).
            LockFunnelCounters.flushIfNeeded()
            // Same pattern for the Live Math Preview engagement counters.
            MathPreviewCounters.flushIfNeeded()
            self.handlePendingDeepLink()
            if self.launchFinished, self.skipFirstRunFlowsForTesting == false {
                self.scheduleWhatsNewIfNeeded()
            }
            // Re-verify entitlements on every foreground after the first, so refunds/revocations
            // (and any tampered group flag) are corrected promptly while StoreKit is ready.
            if self.hasBecomeActiveOnce {
                StoreManager.refreshEntitlementsOnForeground()
                // Surface the in-app updates pre-prompt only on a *subsequent* foreground (never the
                // first cold-launch paint, where hasBecomeActiveOnce is still false), so it lands
                // when the user is re-engaged rather than interrupting first launch. The pure gate
                // inside presentIfNeeded already filters out anyone ineligible/already-asked/decided.
                UpdatesPreprompt.presentIfNeeded(from: self)
            }
            self.hasBecomeActiveOnce = true
            CloudSync.pull()
            // Also attempt the one-time first-run upsell on foreground. The realistic first-run flow
            // enables the keyboard in Settings and returns to a still-running app — which never re-runs
            // finishLaunch(), so a cold-launch-only trigger would miss it. Gated on launchFinished so it
            // can't fire during the initial launch (before the splash/onboarding sequence completes).
            if self.launchFinished {
                self.presentFirstRunUpsellIfNeeded()
            }
        }
        handlePendingDeepLink()
        pendingDeepLinkObserver = NotificationCenter.default.addObserver(forName: .numpadPendingDeepLink, object: pendingDeepLinkDelegate, queue: .main, using: drainDeepLink)

        // Push portable data to iCloud when leaving the foreground (only when Pro + sync is on).
        NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { _ in
            CloudSync.push()
        }

        // Keyboard avoidance for the demo field. willChangeFrame (not just willShow) also fires
        // when the user switches keyboards (NumPad ↔ system — different heights) and on rotation,
        // so the field tracks every height change. willHide restores the resting position.
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChangeFrame(_:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)

        // Respect Reduce Motion: skip the splash zoom/reveal animation and go straight to content.
        if UIAccessibility.isReduceMotionEnabled {
            splashView.removeFromSuperview()
            finishLaunch()
        } else {
            splashView.startAnimation() { [weak self] in
                self?.finishLaunch()
            }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        handlePendingDeepLink()
    }

    /// True when this launch should skip onboarding AND the first-run upsell triggers. DEBUG-only,
    /// driven by the `-skipOnboarding` launch argument XCUITest passes so a screenshot lands on a
    /// clean, deterministic screen instead of racing a modal onboarding/upsell flow. Always `false`
    /// in release builds (`DebugDeepLinkRoute` doesn't exist outside DEBUG).
    var skipFirstRunFlowsForTesting: Bool {
        #if DEBUG
        return DebugDeepLinkRoute.shouldSkipOnboarding
        #else
        return false
        #endif
    }

    /// Post-splash launch work: onboarding, RC/Store start, first-run defaults, and deep-link drain.
    func finishLaunch() {
        // RemoteConfigManager.start() now runs from AppDelegate.didFinishLaunchingWithOptions
        // (process launch), not here (scene/window launch) — so it also runs for headless App
        // Intent launches, which never reach viewDidLoad()/finishLaunch(). It still completes well
        // before this point: `configureDefaults()` runs synchronously inside `start()`, which
        // AppDelegate calls before the scene/window (and therefore this view controller) exist, so
        // `RemoteConfigManager.shared.onboardingEnabled` below still reads a real value on the very
        // first launch.
        if skipFirstRunFlowsForTesting {
            OnboardingFlow.markShown()
        } else {
            presentOnboardingOrInstructionsIfNeeded()
        }
        StoreManager.start()
        CloudSync.start()
        EarlyBird.startIfNeeded()
        // Apply RC defaults to first-run experience once
        if UserDefaults.group.bool(forKey: Constants.rcApplied.rawValue) == false {
            KeyboardTheme.selected = RemoteConfigManager.shared.defaultTheme
            KeyboardType.selected = RemoteConfigManager.shared.defaultPack
            UserDefaults.group.set(true, forKey: Constants.rcApplied.rawValue)
            // Notify the keyboard extension of the RC-derived default theme/pack.
            SettingsSync.post()
        }
        // A notification can arrive while the splash is still running. Mark launch ready before
        // draining it; otherwise both update destinations return and wait for another foreground.
        launchFinished = true
        let handledDeepLink = handlePendingDeepLink()
        if skipFirstRunFlowsForTesting == false, !handledDeepLink {
            presentFirstRunUpsellIfNeeded()
            scheduleWhatsNewIfNeeded()
        }
        #if DEBUG
        handleDebugLaunchArgumentRoutesIfNeeded()
        #endif
    }

    /// Decides between the new 3-step interactive onboarding (fresh installs only, RC-gated) and the
    /// legacy `InstructionsViewController` push (existing users, or onboarding disabled/already
    /// shown). Reads the same "has this install run before" markers `EarlyBird.isExistingPreV2User`
    /// uses, BEFORE `rcApplied` is stamped true below, so a genuinely fresh install is never misread
    /// as existing.
    private func presentOnboardingOrInstructionsIfNeeded() {
        let defaults = UserDefaults.group
        let isExistingUser = EarlyBird.isExistingPreV2User(
            rcApplied: defaults.bool(forKey: Constants.rcApplied.rawValue),
            grandfatherChecked: defaults.bool(forKey: Constants.grandfatherCheckedV2.rawValue),
            firstRunUpsellShown: defaults.bool(forKey: Constants.firstRunUpsellShown.rawValue),
            ownsAnyProduct: Monetization.isProPurchased || !Monetization.ownedPackProductIDs.isEmpty
        )
        let showOnboarding = OnboardingFlow.shouldShow(
            remoteEnabled: RemoteConfigManager.shared.onboardingEnabled,
            onboardingAlreadyShown: OnboardingFlow.alreadyShown,
            keyboardAlreadyEnabled: Keyboard.isKeyboardEnabled,
            isExistingUser: isExistingUser
        )
        if showOnboarding {
            presentOnboarding()
        } else if !Keyboard.isKeyboardEnabled {
            self.show(InstructionsViewController.instantiate(), sender: self)
        }
    }

    /// Presents the interactive first-run onboarding modally. Completion (natural finish or skip)
    /// hands off to the existing new-buyer paywall trigger so onboarding's own completion becomes
    /// that trigger moment — `presentFirstRunUpsellIfNeeded`'s own `presentedViewController == nil`
    /// guards already prevent it from firing a second time while onboarding is still on screen (e.g.
    /// if the user returns from Settings mid-flow and the foreground observer above fires
    /// underneath it).
    private func presentOnboarding() {
        OnboardingFlow.markShown()
        let onboarding = OnboardingViewController { [weak self] in
            guard let self else { return }
            // Onboarding's completion runs after dismissal, so a waiting notification gets the
            // first opportunity to navigate before automatic offers or the recap are scheduled.
            if !self.handlePendingDeepLink() {
                self.presentFirstRunUpsellIfNeeded()
                self.scheduleWhatsNewIfNeeded()
            }
        }
        present(onboarding, animated: !UIAccessibility.isReduceMotionEnabled)
    }

    /// One-time, skippable value paywalls shown once the keyboard is enabled (so they never stack
    /// over onboarding) and only when Pro isn't already owned. Reactive locks remain the primary
    /// upsell; these just give the user one proactive look at what Pro includes. Two
    /// mutually-exclusive funnels, distinguished by an analytics `funnel` attribute and separate
    /// one-time flags so they can never conflate:
    ///  - early_bird: pre-2.0 users in their limited-time 50%-off window (existing behavior).
    ///  - new_buyer: everyone else, gated by Remote Config `first_run_upsell_enabled` and triggered
    ///    by keyboard-enablement detection (`KeyboardEnablementTracker`).
    /// Falls back to the session-count milestone upsell when neither fires this foreground.
    private func presentFirstRunUpsellIfNeeded() {
        // Keyboard-enablement funnel tracking runs on every relevant foreground regardless of the
        // paywall gates below (drives both the `keyboard_enabled` event and the new-buyer trigger).
        let newBuyerTriggerAvailable = KeyboardEnablementTracker.refresh()

        var upsellScheduled = false
        // Don't compete with a deep-link store that's about to present.
        let noPendingDeepLink = (UIApplication.shared.delegate as? AppDelegate)?.pendingURL == nil
        if Monetization.paywallEnabled, Keyboard.isKeyboardEnabled, !Monetization.isProEntitled, noPendingDeepLink {
            if EarlyBird.isCurrentlyActive {
                presentEarlyBirdFirstRunUpsell()
                upsellScheduled = true
            } else if newBuyerTriggerAvailable {
                presentNewBuyerFirstRunUpsell()
                upsellScheduled = true
            }
        }
        if !upsellScheduled {
            presentSessionMilestoneUpsellIfNeeded()
        }
    }

    /// Early-bird funnel: pre-2.0 users in their 50%-off window. source = "first_run".
    private var canPresentDelayedOffer: Bool {
        AppOfferPresentation.canPresent(
            isActive: UIApplication.shared.applicationState == .active,
            isVisible: isViewLoaded && view.window != nil,
            hasModal: presentedViewController != nil,
            isTopController: navigationController.map { $0.topViewController === self } ?? true,
            hasPendingDeepLink: (UIApplication.shared.delegate as? AppDelegate)?.pendingURL != nil)
    }

    private func presentEarlyBirdFirstRunUpsell() {
        guard UserDefaults.group.bool(forKey: Constants.firstRunUpsellShown.rawValue) == false else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            // Re-check at fire time and consume the one-shot flag ONLY when we actually present —
            // otherwise a modal that happens to be on screen at this instant would silently burn the
            // upsell forever. Re-reading the flag (plus main-queue serialization) also dedupes
            // overlapping triggers from finishLaunch + a near-simultaneous foreground.
            guard let self = self,
                  self.canPresentDelayedOffer,
                  Monetization.paywallEnabled,
                  Keyboard.isKeyboardEnabled,
                  !Monetization.isProEntitled,
                  EarlyBird.isCurrentlyActive,
                  UserDefaults.group.bool(forKey: Constants.firstRunUpsellShown.rawValue) == false
            else { return }
            UserDefaults.group.set(true, forKey: Constants.firstRunUpsellShown.rawValue)
            Analytics.logEvent(name: "first_run_upsell_shown", attributes: ["funnel": "early_bird"])
            let store = StoreViewController()
            store.source = "first_run"
            self.show(store, sender: self)
        }
    }

    /// New-buyer funnel: everyone not early-bird-eligible, triggered the first time keyboard
    /// enablement is detected (or deferred to the next launch when the keyboard was already
    /// enabled at the very first observation — see `KeyboardEnablementTracker`). source = "first_run".
    private func presentNewBuyerFirstRunUpsell() {
        guard RemoteConfigManager.shared.firstRunUpsellEnabled, NewBuyerUpsell.shown == false else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self = self,
                  self.canPresentDelayedOffer,
                  Monetization.paywallEnabled,
                  Keyboard.isKeyboardEnabled,
                  !Monetization.isProEntitled,
                  !EarlyBird.isCurrentlyActive,
                  RemoteConfigManager.shared.firstRunUpsellEnabled,
                  NewBuyerUpsell.shown == false
            else { return }
            NewBuyerUpsell.shown = true
            KeyboardEnablementTracker.consumeNewBuyerTrigger()
            Analytics.logEvent(name: "first_run_upsell_shown", attributes: ["funnel": "new_buyer"])
            let store = StoreViewController()
            store.source = "first_run"
            self.show(store, sender: self)
        }
    }

    /// Session-count milestone upsell (Remote Config `upsell_after_sessions`, default 8), shown at
    /// most once ever. source = "session_milestone".
    private func presentSessionMilestoneUpsellIfNeeded() {
        let noPendingDeepLink = (UIApplication.shared.delegate as? AppDelegate)?.pendingURL == nil
        guard Monetization.paywallEnabled, noPendingDeepLink,
              SessionMilestone.shouldPresent(sessionCount: SessionMilestone.sessionCount,
                                             threshold: RemoteConfigManager.shared.upsellAfterSessions,
                                             isProEntitled: Monetization.isProEntitled,
                                             keyboardEnabled: Keyboard.isKeyboardEnabled,
                                             alreadyShown: SessionMilestone.shown)
        else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self = self,
                  self.canPresentDelayedOffer,
                  Monetization.paywallEnabled,
                  !Monetization.isProEntitled,
                  Keyboard.isKeyboardEnabled,
                  SessionMilestone.shouldPresent(sessionCount: SessionMilestone.sessionCount,
                      threshold: RemoteConfigManager.shared.upsellAfterSessions,
                      isProEntitled: Monetization.isProEntitled,
                      keyboardEnabled: Keyboard.isKeyboardEnabled,
                      alreadyShown: SessionMilestone.shown)
            else { return }
            SessionMilestone.shown = true
            let store = StoreViewController()
            store.source = "session_milestone"
            self.show(store, sender: self)
        }
    }

    /// Delayed so first-run upsell (0.6s push) and onboarding can take the screen first.
    /// The gate does not consume the one-shot unless the sheet actually presents.
    private func scheduleWhatsNewIfNeeded() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            WhatsNewViewController.presentIfNeeded(from: self)
        }
    }

    var pendingDeepLinkDelegate: AppDelegate? {
        UIApplication.shared.delegate as? AppDelegate
    }

    @discardableResult
    func handlePendingDeepLink() -> Bool {
        guard
            let appDelegate = pendingDeepLinkDelegate,
            let url = appDelegate.pendingURL
        else {
            deepLinkRetry?.cancel()
            deepLinkRetry = nil
            return false
        }
        if let route = AppDeepLink.parse(url) {
            switch route {
            case .storePreview(let source):
                appDelegate.pendingURL = nil
                let store = StoreViewController()
                store.source = source ?? "deep_link"
                show(store, sender: self)
            case .appStore:
                guard updateDeepLinkPresenter != nil else {
                    retryPendingDeepLinkAfterPresentation()
                    return false
                }
                appDelegate.pendingURL = nil
                openUpdateAppStore()
            case .whatsNew:
                guard let presenter = updateDeepLinkPresenter else {
                    retryPendingDeepLinkAfterPresentation()
                    return false
                }
                appDelegate.pendingURL = nil
                WhatsNewViewController.present(from: presenter, force: true)
            }
            deepLinkRetry?.cancel()
            deepLinkRetry = nil
            return true
        }
        appDelegate.pendingURL = nil
        #if DEBUG
        if let route = DebugDeepLinkRoute.parse(url) {
            handleDebugDeepLink(route)
            return true
        }
        #endif
        return false
    }

    private var updateDeepLinkPresenter: UIViewController? {
        let presenter = navigationController?.topViewController ?? self
        guard launchFinished,
              UIApplication.shared.applicationState == .active,
              presenter.viewIfLoaded?.window != nil,
              presentedViewController == nil,
              navigationController?.presentedViewController == nil,
              presenter.presentedViewController == nil,
              !presenter.isBeingPresented, !presenter.isBeingDismissed,
              presenter.transitionCoordinator == nil else { return nil }
        return presenter
    }

    /// Page-sheet dismissal does not reliably cause the presenting controller to appear again.
    /// Retry only while a URL is pending and the app is active; foreground/launch callbacks resume
    /// a deferred route after backgrounding. Do not replace a modal's existing presentation delegate.
    private func retryPendingDeepLinkAfterPresentation() {
        guard launchFinished, UIApplication.shared.applicationState == .active,
              deepLinkRetry == nil else { return }
        let retry = DispatchWorkItem { [weak self] in
            self?.deepLinkRetry = nil
            self?.handlePendingDeepLink()
        }
        deepLinkRetry = retry
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: retry)
    }

    func openUpdateAppStore() {
        UIApplication.shared.open(UpdateNotificationPolicy.appStoreURL)
    }

    #if DEBUG
    /// Executes a parsed `numpad://debug/...` route. DEBUG-only, mirroring the Store screen's own
    /// DEBUG section — lets the Simulator be driven via `simctl openurl` without a tap driver.
    private func handleDebugDeepLink(_ route: DebugDeepLinkRoute) {
        switch route {
        case .entitlePro(let isEntitled):
            Monetization.debugProOverride = isEntitled
            SettingsSync.post()
        case .heightPreset(let preset):
            KeyboardHeightPreset.selected = preset
            SettingsSync.post()
        case .heightScreen:
            show(KeyboardHeightViewController(), sender: self)
        case .customKeyboardEditor:
            show(CustomKeyboardEditorViewController(), sender: self)
        case .typingSurface:
            present(DebugTypingViewController(), animated: true)
        case .featuresGuide:
            show(FeaturesGuideViewController(), sender: self)
        }
    }

    /// Executes every `-debugRoute <value>` launch-argument pair the same way `handlePendingDeepLink()`
    /// executes a parsed `numpad://debug/...` URL — the launch-argument counterpart described on
    /// `DebugDeepLinkRoute.parseAll(fromLaunchArguments:)`. Called once, after the splash/onboarding
    /// sequence in `finishLaunch()` has settled, since ProcessInfo's arguments never change mid-process
    /// (unlike `pendingURL`, there's no race to re-drain on a later foreground).
    private func handleDebugLaunchArgumentRoutesIfNeeded() {
        for route in DebugDeepLinkRoute.parseAll(fromLaunchArguments: ProcessInfo.processInfo.arguments) {
            handleDebugDeepLink(route)
        }
    }
    #endif

    deinit {
        deepLinkRetry?.cancel()
        if let observer = deepLinkObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = pendingDeepLinkObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    // MARK: - Keyboard avoidance

    @objc private func keyboardWillChangeFrame(_ notification: Notification) {
        guard
            let userInfo = notification.userInfo,
            let endFrame = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
        else { return }
        // Convert the keyboard frame into this view's coordinate space, then measure the
        // overlap with our bounds. During an interactive dismiss or when the keyboard is
        // off-screen the overlap is zero and the field returns to its resting position.
        let endFrameInView = view.convert(endFrame, from: view.window)
        let overlap = max(0, view.bounds.maxY - endFrameInView.minY)
        // The bottom constraint is relative to the safe area; subtract the bottom safe-area
        // inset that's already accounted for so the field sits `demoFieldBottomInset` above
        // the keyboard, not double-offset on home-indicator devices.
        let safeBottom = view.safeAreaInsets.bottom
        let adjusted = max(0, overlap - safeBottom)
        applyDemoFieldOffset(-(demoFieldBottomInset + adjusted), userInfo: userInfo)
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        applyDemoFieldOffset(-demoFieldBottomInset, userInfo: notification.userInfo)
    }

    private func applyDemoFieldOffset(_ constant: CGFloat, userInfo: [AnyHashable: Any]?) {
        guard let constraint = demoFieldBottomConstraint, constraint.constant != constant else { return }
        constraint.constant = constant
        let duration = (userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval) ?? 0.25
        let curveRaw = (userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? Int) ?? UIView.AnimationCurve.easeInOut.rawValue
        let options = UIView.AnimationOptions(rawValue: UInt(curveRaw) << 16)
        UIView.animate(withDuration: duration, delay: 0, options: [options, .beginFromCurrentState], animations: {
            self.view.layoutIfNeeded()
        })
        // Keep the settings list scrollable above the raised field. On iOS 15+ UIScrollView
        // already insets itself for the keyboard automatically; we only add the demo field's
        // own height + padding on top of that while the keyboard is up.
        let fieldExtra: CGFloat = constant == -demoFieldBottomInset ? 0 : 44 + demoFieldBottomInset
        tableView.tableView.contentInset.bottom = fieldExtra
        tableView.tableView.verticalScrollIndicatorInsets.bottom = fieldExtra
    }

}
