//
//  KeyboardEnablementTracker.swift
//  NumPad
//
//  App target only — the keyboard extension never logs analytics. Tracks whether the NumPad
//  keyboard has been added in Settings (`Keyboard.isKeyboardEnabled`) across app foregrounds, so
//  callers can react to it becoming enabled without re-deriving "is this a genuine transition"
//  logic in more than one place.
//

import Foundation

enum KeyboardEnablementTracker {

    /// One resolved observation of the enablement state.
    struct Resolution: Equatable {
        /// Log the one-time `keyboard_enabled` analytics event on this call.
        let shouldLogKeyboardEnabled: Bool
        /// A trigger point for the new-buyer proactive-paywall funnel is available right now:
        /// either a live false -> true transition, or a deferred trigger carried over from a prior
        /// observation that found the keyboard already enabled.
        let newBuyerTriggerAvailable: Bool
        /// Persist as the deferred-trigger state for the next observation.
        let nextDeferredTrigger: Bool
    }

    /// Pure decision table — no UserDefaults/Analytics access, so it's unit-testable directly.
    ///
    /// - `baselineEstablished`: false only on the very first observation this install has ever made.
    ///   There's nothing to compare it against, so a live transition can never be claimed here.
    /// - `deferredTrigger`: carried over from a prior call where the keyboard was already enabled on
    ///   that very first observation — deferred here so a cold launch is never ambushed with a
    ///   paywall the instant the app notices a pre-existing keyboard; it fires on the next
    ///   observation instead.
    static func resolve(baselineEstablished: Bool, previouslyEnabled: Bool, nowEnabled: Bool,
                         deferredTrigger: Bool, keyboardEnabledEventAlreadyLogged: Bool) -> Resolution {
        guard baselineEstablished else {
            return Resolution(shouldLogKeyboardEnabled: false, newBuyerTriggerAvailable: false, nextDeferredTrigger: nowEnabled)
        }
        if deferredTrigger {
            return Resolution(shouldLogKeyboardEnabled: false, newBuyerTriggerAvailable: nowEnabled, nextDeferredTrigger: false)
        }
        let transitioned = !previouslyEnabled && nowEnabled
        return Resolution(
            shouldLogKeyboardEnabled: transitioned && !keyboardEnabledEventAlreadyLogged,
            newBuyerTriggerAvailable: transitioned,
            nextDeferredTrigger: false
        )
    }

    // MARK: - Runtime (app target)

    @UserDefault(key: Constants.keyboardEnablementBaselineEstablished.rawValue, defaultValue: false, userDefaults: .group)
    private static var baselineEstablished: Bool
    @UserDefault(key: Constants.keyboardEnabledLastKnown.rawValue, defaultValue: false, userDefaults: .group)
    private static var lastKnownEnabled: Bool
    @UserDefault(key: Constants.keyboardEnabledEventLogged.rawValue, defaultValue: false, userDefaults: .group)
    private static var eventLogged: Bool
    @UserDefault(key: Constants.newBuyerUpsellDeferredTrigger.rawValue, defaultValue: false, userDefaults: .group)
    private static var deferredTrigger: Bool
    @UserDefault(key: Constants.newBuyerUpsellTriggerPending.rawValue, defaultValue: false, userDefaults: .group)
    private static var triggerPending: Bool

    /// Call once per app foreground (before any first-run-upsell gating runs). Persists the latest
    /// enablement state, logs the one-time `keyboard_enabled` event on the first observed
    /// enablement, and returns whether the new-buyer upsell funnel has a trigger point available.
    ///
    /// The underlying false->true transition can only ever be observed once (`lastKnownEnabled` is
    /// updated below regardless of what the caller does with the result), so the trigger is latched
    /// into `triggerPending` rather than returned as a one-shot value — if the caller's presentation
    /// guard fails at fire time, the next call still reports the trigger instead of losing it.
    /// Callers must call `consumeNewBuyerTrigger()` once presentation actually happens.
    @discardableResult
    static func refresh(nowEnabled: Bool = Keyboard.isKeyboardEnabled) -> Bool {
        let resolution = resolve(baselineEstablished: baselineEstablished, previouslyEnabled: lastKnownEnabled,
                                  nowEnabled: nowEnabled, deferredTrigger: deferredTrigger,
                                  keyboardEnabledEventAlreadyLogged: eventLogged)
        if resolution.shouldLogKeyboardEnabled {
            Analytics.logEvent(name: "keyboard_enabled")
            eventLogged = true
        }
        deferredTrigger = resolution.nextDeferredTrigger
        lastKnownEnabled = nowEnabled
        baselineEstablished = true
        if resolution.newBuyerTriggerAvailable {
            triggerPending = true
        }
        return triggerPending
    }

    /// Call once the new-buyer upsell has actually been presented (not merely attempted), so a
    /// consumed trigger doesn't keep re-arming on every subsequent foreground.
    static func consumeNewBuyerTrigger() {
        triggerPending = false
    }
}

/// The proactive first-run paywall for new (post-2.0) buyers who are NOT early-bird eligible.
/// Uses a distinct one-time flag from the early-bird funnel's `firstRunUpsellShown`, so the two
/// funnels can never be conflated in analytics or accidentally consume each other's one shot.
enum NewBuyerUpsell {
    @UserDefault(key: Constants.newBuyerUpsellShown.rawValue, defaultValue: false, userDefaults: .group)
    static var shown: Bool

    /// Pure gate — unit-tested independent of UserDefaults/Remote Config.
    static func shouldPresent(featureEnabled: Bool, isProEntitled: Bool, earlyBirdEligible: Bool,
                              alreadyShown: Bool, triggerAvailable: Bool) -> Bool {
        featureEnabled && !isProEntitled && !earlyBirdEligible && !alreadyShown && triggerAvailable
    }
}

/// Combined gate for BOTH first-run presenters (early_bird and new_buyer). Session-milestone
/// upsell is a separate funnel and is not decided here.
enum FirstRunUpsell {
    /// Pure gate — unit-tested independent of UserDefaults/Remote Config/UIKit.
    /// `featureEnabled` is a master switch: when it is off, neither funnel opens the Store,
    /// even if Early Bird is active or a new-buyer trigger is available.
    static func shouldPresent(
        featureEnabled: Bool,
        paywallEnabled: Bool,
        keyboardEnabled: Bool,
        isProEntitled: Bool,
        hasPendingDeepLink: Bool,
        earlyBirdActive: Bool,
        earlyBirdAlreadyShown: Bool,
        newBuyerTriggerAvailable: Bool,
        newBuyerAlreadyShown: Bool
    ) -> Bool {
        guard featureEnabled, paywallEnabled, keyboardEnabled, !isProEntitled, !hasPendingDeepLink else { return false }
        if earlyBirdActive {
            return !earlyBirdAlreadyShown
        }
        if newBuyerTriggerAvailable {
            return !newBuyerAlreadyShown
        }
        return false
    }
}
