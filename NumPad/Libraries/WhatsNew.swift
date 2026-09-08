//
//  WhatsNew.swift
//  NumPad
//
//  2.0.3 one-shot What's New gate for the container app's recap sheet.
//  Not the first-run Pro upsell, not onboarding, not the EarlyBird UpdatesPreprompt.
//

import Foundation

enum WhatsNew {
    /// Marketing version this cut's recap belongs to. Bump when a later cut ships its own sheet.
    static let cutVersion = "2.0.3"

    static let deepLinkURLString = "numpad://whats-new"

    @UserDefault(key: Constants.whatsNewLastSeenVersion.rawValue, defaultValue: "", userDefaults: .group)
    private static var storedLastSeen: String

    @UserDefault(key: Constants.whatsNewNotificationScheduled.rawValue, defaultValue: false, userDefaults: .group)
    static var notificationScheduled: Bool

    /// `nil` when this install has never marked the 2.0.3 recap seen.
    static var lastSeenVersion: String? {
        storedLastSeen.isEmpty ? nil : storedLastSeen
    }

    static var currentVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? cutVersion
    }

    /// Show the sheet when `current` is this cut or newer and `lastSeen`
    /// is missing or older than the cut. Pure — unit-tested without UserDefaults.
    static func shouldPresent(lastSeen: String?, current: String) -> Bool {
        guard compareVersions(current, cutVersion) != .orderedAscending else { return false }
        guard let lastSeen, !lastSeen.isEmpty else { return true }
        return compareVersions(lastSeen, cutVersion) == .orderedAscending
    }

    /// Dismissal is a permanent keyboard-only choice, independent of recap seen-state and
    /// notification permission. Private extension defaults work with Full Access off and on.
    static func dismissBanner(defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: Constants.whatsNewBannerDismissed.rawValue)
    }

    static func isChipVisible(lastSeen: String?, current: String,
                              defaults: UserDefaults = .standard) -> Bool {
        !defaults.bool(forKey: Constants.whatsNewBannerDismissed.rawValue)
            && shouldPresent(lastSeen: lastSeen, current: current)
    }

    static var isChipVisibleNow: Bool {
        isChipVisible(lastSeen: lastSeenVersion, current: currentVersion)
    }

    /// Skip auto-present when onboarding (modal) or a pushed paywall/settings screen is up.
    static func canPresent(hasModal: Bool, navShowingOtherScreen: Bool) -> Bool {
        !hasModal && !navShowingOtherScreen
    }

    static func matchesDeepLink(_ url: URL) -> Bool {
        url.scheme == "numpad" && url.host == "whats-new"
    }

    /// Consume the one-shot. Call when the sheet is actually presented (not merely decided),
    /// so subsequent launches do not automatically present the recap again.
    static func markSeen(_ version: String = cutVersion) {
        storedLastSeen = version
        SettingsSync.post()
    }
}

extension WhatsNew {
    /// Dotted numeric compare (`2.0` < `2.0.2` < `2.0.3`). Missing trailing components count as 0.
    static func compareVersions(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let left = lhs.split(separator: ".").compactMap { Int($0) }
        let right = rhs.split(separator: ".").compactMap { Int($0) }
        let count = max(left.count, right.count)
        for index in 0..<count {
            let a = index < left.count ? left[index] : 0
            let b = index < right.count ? right[index] : 0
            if a < b { return .orderedAscending }
            if a > b { return .orderedDescending }
        }
        return .orderedSame
    }
}
