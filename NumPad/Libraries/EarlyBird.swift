//
//  EarlyBird.swift
//  NumPad
//
//  72h discounted Pro (`ProductCatalog.proEarlyBird`, ~$5.99).
//  Originally pre-2.0 installs only. From 2.0.2: open to all non-Pro installs so the storefront
//  $5.99 Early Bird is actually purchasable (owner decision 2026-08-02 — explore discounts,
//  keep paid front door).
//

import Foundation
import UserNotifications

/// On first launch we record a window-start timestamp. Eligible non-Pro users can buy Pro at the
/// early-bird SKU for 72 hours, and may receive two reminders: 1 hour after window start, and
/// 6 hours before the window closes. App target only (the keyboard never schedules notifications).
enum EarlyBird {
    static let windowDuration: TimeInterval = 72 * 3600
    static let firstNotifyAfter: TimeInterval = 1 * 3600     // 1h after window start
    static let secondNotifyAfter: TimeInterval = 66 * 3600   // = 72h − 6h (6h before the window ends)
    private static let notify1ID = "numpad.earlybird.reminder1"
    private static let notify2ID = "numpad.earlybird.reminder2"

    // Persisted in the app group.
    @UserDefault(key: Constants.firstV2LaunchTimestamp.rawValue, defaultValue: 0, userDefaults: .group)
    private static var firstLaunchTS: Double
    @UserDefault(key: Constants.earlyBirdEligibleUser.rawValue, defaultValue: false, userDefaults: .group)
    private static var eligibleUser: Bool
    @UserDefault(key: Constants.earlyBirdInitialized.rawValue, defaultValue: false, userDefaults: .group)
    private static var initialized: Bool
    @UserDefault(key: Constants.earlyBirdOpenedToAllV202.rawValue, defaultValue: false, userDefaults: .group)
    private static var openedToAllV202: Bool

    // MARK: - Pure logic (unit-tested)

    /// A pre-2.0 user — recognised by any marker a 1.x launch leaves behind.
    /// Kept for analytics / copy; eligibility itself is open to all non-Pro from 2.0.2.
    static func isExistingPreV2User(rcApplied: Bool, grandfatherChecked: Bool, firstRunUpsellShown: Bool, ownsAnyProduct: Bool) -> Bool {
        rcApplied || grandfatherChecked || firstRunUpsellShown || ownsAnyProduct
    }

    /// `[start, start + duration)` — inclusive of the start instant, exclusive of the end.
    static func isWithinWindow(now: Date, start: Date, duration: TimeInterval = windowDuration) -> Bool {
        let elapsed = now.timeIntervalSince(start)
        return elapsed >= 0 && elapsed < duration
    }

    /// Whether the discounted offer should be surfaced right now. `windowDuration` defaults to the
    /// hardcoded 72h constant (kept Firebase-free for pure unit tests); the runtime caller
    /// (`isCurrentlyActive`) passes the Remote-Config-derived value explicitly instead.
    static func isOfferActive(now: Date, startTimestamp: Double, eligibleUser: Bool, isProEntitled: Bool,
                               windowDuration: TimeInterval = EarlyBird.windowDuration) -> Bool {
        guard eligibleUser, !isProEntitled, startTimestamp > 0 else { return false }
        return isWithinWindow(now: now, start: Date(timeIntervalSince1970: startTimestamp), duration: windowDuration)
    }

    /// Pure migration decision for 2.0.2 "open to all new buyers".
    /// Grants a **fresh** window only when the install initialized under the old rule as ineligible
    /// and still isn't Pro — never re-opens for users who already exhausted a real window.
    static func shouldGrantOpenToAllMigration(alreadyMigrated: Bool, initialized: Bool,
                                             eligibleUser: Bool, isProEntitled: Bool) -> Bool {
        !alreadyMigrated && initialized && !eligibleUser && !isProEntitled
    }

    /// Whether to surface the in-app notifications pre-prompt (which gates the system permission
    /// dialog). Only for eligible users while the offer is still active, shown at most once, and
    /// never once the user has already decided notification authorization in Settings.
    static func shouldOfferUpdatesPrompt(eligibleUser: Bool, offerActive: Bool,
                                         alreadyAsked: Bool, authDetermined: Bool) -> Bool {
        eligibleUser && offerActive && !alreadyAsked && !authDetermined
    }

    // MARK: - Runtime (app target)

    /// Live offer state from the persisted window start + current entitlement. Reads the window
    /// length from Remote Config (`early_bird_window_hours`), with a hardcoded 72h fallback baked
    /// into both `RemoteConfigManager.earlyBirdWindowHours` and `windowDuration` above.
    static var isCurrentlyActive: Bool {
        isOfferActive(now: Date(), startTimestamp: firstLaunchTS, eligibleUser: eligibleUser, isProEntitled: Monetization.isProEntitled,
                      windowDuration: RemoteConfigManager.shared.earlyBirdWindowHours * 3600)
    }

    /// Call once per launch. Migrates older ineligible installs, then on the very first stamp
    /// opens the 72h window to every non-Pro install (not only pre-2.0). Notification auth is
    /// driven later by the in-app updates pre-prompt — never at launch.
    static func startIfNeeded() {
        migrateOpenToAllNewBuyersIfNeeded()
        guard !initialized else { return }
        initialized = true
        firstLaunchTS = Date().timeIntervalSince1970
        // 2.0.2: launch discount open to all non-Pro. `isOfferActive` still requires !isProEntitled.
        eligibleUser = true
        openedToAllV202 = true
    }

    /// One-shot: installs that first-ran under the pre-2.0-only rule with `eligibleUser = false`
    /// (new buyers who saw $5.99 on the store page but could never purchase) get a real window.
    private static func migrateOpenToAllNewBuyersIfNeeded() {
        guard shouldGrantOpenToAllMigration(
            alreadyMigrated: openedToAllV202,
            initialized: initialized,
            eligibleUser: eligibleUser,
            isProEntitled: Monetization.isProEntitled
        ) else {
            openedToAllV202 = true
            return
        }
        eligibleUser = true
        firstLaunchTS = Date().timeIntervalSince1970
        openedToAllV202 = true
    }

    /// Cancel pending reminders — call after a Pro purchase.
    static func cancelReminders() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notify1ID, notify2ID])
    }

    /// Called by the in-app updates pre-prompt after the user opts in to receiving updates.
    /// Requests notification authorization (the only place the OS permission dialog is triggered)
    /// and, if granted, schedules the early-bird reminders. The permission is now obtained via the
    /// in-app pre-prompt rather than unprompted at launch.
    static func requestUpdatesAuthorizationThenSchedule() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            addReminders()
        }
    }

    private static func addReminders() {
        add(id: notify1ID, after: firstNotifyAfter,
            title: NSLocalizedString("Your early-bird 50% off NumPad Pro", comment: "Early-bird reminder title"),
            body: NSLocalizedString("Unlock every pack, the custom keyboard and more at half price. Limited time.", comment: "Early-bird reminder body"))
        add(id: notify2ID, after: secondNotifyAfter,
            title: NSLocalizedString("Your 50% off ends soon", comment: "Early-bird last-chance reminder title"),
            body: NSLocalizedString("Only a few hours left to unlock NumPad Pro at half price.", comment: "Early-bird last-chance reminder body"))
    }

    private static func add(id: String, after: TimeInterval, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: after, repeats: false)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
}
