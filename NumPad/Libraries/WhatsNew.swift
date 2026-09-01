//
//  WhatsNew.swift
//  NumPad
//
//  2.0.3 one-shot What's New gate. Shared by the container (sheet) and the keyboard (chip).
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

    /// Show the sheet (and the keyboard chip) when `current` is this cut or newer and `lastSeen`
    /// is missing or older than the cut. Pure — unit-tested without UserDefaults.
    static func shouldPresent(lastSeen: String?, current: String) -> Bool {
        guard compareVersions(current, cutVersion) != .orderedAscending else { return false }
        guard let lastSeen, !lastSeen.isEmpty else { return true }
        return compareVersions(lastSeen, cutVersion) == .orderedAscending
    }

    /// Same flag as the sheet. The keyboard chip is visible until the container marks seen.
    static func isChipVisible(lastSeen: String?, current: String) -> Bool {
        shouldPresent(lastSeen: lastSeen, current: current)
    }

    /// Skip auto-present when onboarding (modal) or a pushed paywall/settings screen is up.
    static func canPresent(hasModal: Bool, navShowingOtherScreen: Bool) -> Bool {
        !hasModal && !navShowingOtherScreen
    }

    static func matchesDeepLink(_ url: URL) -> Bool {
        url.scheme == "numpad" && url.host == "whats-new"
    }

    static var isChipVisibleNow: Bool {
        isChipVisible(lastSeen: lastSeenVersion, current: currentVersion)
    }

    /// Consume the one-shot. Call when the sheet is actually presented (not merely decided),
    /// so the keyboard chip hides on the next appearance / SettingsSync.
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
