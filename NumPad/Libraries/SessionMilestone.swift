//
//  SessionMilestone.swift
//  NumPad
//
//  App target only. Session-count milestone upsell: after N sessions without buying Pro (Remote
//  Config `upsell_after_sessions`, default 8), show one proactive look at the Store. Fires at most
//  once, ever, and only once the keyboard is enabled — so it never doubles up with the
//  enablement-driven first-run funnels (see `KeyboardEnablementTracker` / `NewBuyerUpsell`).
//

import Foundation

enum SessionMilestone {
    @UserDefault(key: Constants.sessionCount.rawValue, defaultValue: 0, userDefaults: .group)
    static var sessionCount: Int

    @UserDefault(key: Constants.sessionMilestoneUpsellShown.rawValue, defaultValue: false, userDefaults: .group)
    static var shown: Bool

    /// Pure gate — unit-tested independent of UserDefaults/Remote Config.
    static func shouldPresent(sessionCount: Int, threshold: Int, isProEntitled: Bool,
                              keyboardEnabled: Bool, alreadyShown: Bool) -> Bool {
        !alreadyShown && keyboardEnabled && !isProEntitled && sessionCount >= threshold
    }

    /// Call from the app's background transition (`AppDelegate.applicationWillResignActive`),
    /// alongside the existing `session` analytics event.
    static func recordSession() {
        sessionCount += 1
    }
}
