//
//  LockFunnelCounters.swift
//  NumPad / Keyboard
//
//  Shared (both targets). O(1), allocation-free counters the keyboard extension bumps for the
//  paywall lock funnel, since the extension has no Firebase. The app reads + zeroes them on every
//  foreground and logs a single aggregated `keyboard_lock_funnel` analytics event when any counter
//  is non-zero, so a burst of extension activity is never reported more than once.
//

import Foundation

enum LockFunnelCounters {
    @UserDefault(key: Constants.lockImpressions.rawValue, defaultValue: 0, userDefaults: .group)
    static var lockImpressions: Int
    @UserDefault(key: Constants.lockedKeyTaps.rawValue, defaultValue: 0, userDefaults: .group)
    static var lockedKeyTaps: Int
    @UserDefault(key: Constants.storeDeeplinkOpens.rawValue, defaultValue: 0, userDefaults: .group)
    static var storeDeeplinkOpens: Int

    // MARK: - Extension side (increment only; called from the keyboard's UI/tap handling)

    static func incrementLockImpressions() { lockImpressions += 1 }
    static func incrementLockedKeyTaps() { lockedKeyTaps += 1 }
    static func incrementStoreDeeplinkOpens() { storeDeeplinkOpens += 1 }

    // MARK: - App side (read + flush)

    /// A point-in-time read of the three counters — pure and unit-testable without touching
    /// UserDefaults.
    struct Snapshot: Equatable {
        let lockImpressions: Int
        let lockedKeyTaps: Int
        let storeDeeplinkOpens: Int

        var hasActivity: Bool { lockImpressions > 0 || lockedKeyTaps > 0 || storeDeeplinkOpens > 0 }
        var analyticsAttributes: [String: Any] {
            ["lock_impressions": lockImpressions, "locked_key_taps": lockedKeyTaps, "store_deeplink_opens": storeDeeplinkOpens]
        }
    }

    /// Call once per app foreground. Logs one aggregated event when any counter is non-zero, then
    /// zeroes all three so they're never double-reported.
    static func flushIfNeeded() {
        let snapshot = Snapshot(lockImpressions: lockImpressions, lockedKeyTaps: lockedKeyTaps, storeDeeplinkOpens: storeDeeplinkOpens)
        guard snapshot.hasActivity else { return }
        Analytics.logEvent(name: "keyboard_lock_funnel", attributes: snapshot.analyticsAttributes)
        lockImpressions = 0
        lockedKeyTaps = 0
        storeDeeplinkOpens = 0
    }
}
