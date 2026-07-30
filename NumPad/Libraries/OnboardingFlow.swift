//
//  OnboardingFlow.swift
//  NumPad
//
//  Pure decision logic for the interactive first-run onboarding (WOW / ENABLE / TRY IT). Kept
//  UIKit-free so "should this install see onboarding" is unit-testable without a live view
//  hierarchy, mirroring the KeyboardEnablementTracker/EarlyBird pattern (pure functions + a thin
//  runtime layer below). App target only — onboarding is a container-app concept; the Keyboard
//  extension never presents it.
//

import Foundation

enum OnboardingFlow {

    /// The first-install sequence for a given device. Existing users never reach this sequence,
    /// but keeping that condition explicit makes the iPad-only height decision independently
    /// verifiable and prevents an update from inserting a new interruption.
    static func steps(isPad: Bool, isFirstInstall: Bool) -> [OnboardingStep] {
        guard isFirstInstall else { return [.wow, .enable, .tryIt] }
        return isPad ? [.wow, .enable, .height, .tryIt] : [.wow, .enable, .tryIt]
    }

    /// Pure gate: should onboarding be shown for this launch?
    ///
    /// - `remoteEnabled`: the `onboarding_enabled` Remote Config kill switch.
    /// - `onboardingAlreadyShown`: the one-shot flag, set the moment onboarding is actually
    ///   presented (see `markShown`) — never merely decided.
    /// - `keyboardAlreadyEnabled`: a user who already has the keyboard enabled has nothing left to
    ///   "enable", so the ENABLE step (and the WOW/TRY-IT bookends) would be pointless.
    /// - `isExistingUser`: reuses `EarlyBird.isExistingPreV2User`'s exact definition of "this install
    ///   has a launch history" (any marker a prior launch would have left behind) — onboarding is a
    ///   fresh-install-only experience, so any of those markers disqualifies it. Existing users
    ///   updating must never see onboarding, even if they never enabled the keyboard.
    static func shouldShow(remoteEnabled: Bool, onboardingAlreadyShown: Bool,
                            keyboardAlreadyEnabled: Bool, isExistingUser: Bool) -> Bool {
        remoteEnabled && !onboardingAlreadyShown && !keyboardAlreadyEnabled && !isExistingUser
    }

    // MARK: - Runtime (app target)

    @UserDefault(key: Constants.onboardingShown.rawValue, defaultValue: false, userDefaults: .group)
    private static var stored: Bool

    /// Whether this install has already been shown onboarding. Read BEFORE `markShown()` is called
    /// for the current launch's decision.
    static var alreadyShown: Bool { stored }

    /// Consume the one-shot flag. Call ONLY once onboarding is actually about to be presented (not
    /// merely decided) — mirrors the "only consume the flag when we actually present" pattern used
    /// by the first-run upsell flags in `ViewController`.
    static func markShown() {
        stored = true
    }
}

/// Narrow, dependency-injected writer for the optional iPad onboarding height choice. It has no
/// profile or policy authority: a locked Kiosk tap can only request Pro, never mutate state.
struct OnboardingHeightSelection {
    enum Outcome: Equatable { case selected, requiresPro }

    private let defaults: UserDefaults
    private let isKioskEntitled: () -> Bool
    private let postSettingsSync: () -> Void

    init(
        defaults: UserDefaults = .group,
        isKioskEntitled: @escaping () -> Bool = { Monetization.isKioskHeightEntitled },
        postSettingsSync: @escaping () -> Void = { SettingsSync.post() }
    ) {
        self.defaults = defaults
        self.isKioskEntitled = isKioskEntitled
        self.postSettingsSync = postSettingsSync
    }

    @discardableResult
    func select(_ preset: KeyboardHeightPreset) -> Outcome {
        guard preset != .kiosk || isKioskEntitled() else { return .requiresPro }
        defaults.set(preset.rawValue, forKey: Constants.heightPreset.rawValue)
        postSettingsSync()
        return .selected
    }

    /// Skipping is intentionally a no-op: it preserves the app group's existing/default height.
    func skip() {}
}
