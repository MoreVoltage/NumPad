//
//  EarlyBird.swift
//  NumPad
//
//  The 50%-off early-bird Pro promo for users who had NumPad before 2.0.
//

import Foundation
import UserNotifications

/// On the first 2.0 launch we record a window-start timestamp and whether this install is an
/// existing (pre-2.0) user. Eligible non-Pro users can buy Pro at half price
/// (`ProductCatalog.proEarlyBird`) for 72 hours, and receive two reminders: 1 hour after updating,
/// and 6 hours before the window closes. App target only (the keyboard never schedules notifications).
enum EarlyBird {
    static let windowDuration: TimeInterval = 72 * 3600
    static let firstNotifyAfter: TimeInterval = 1 * 3600     // 1h after the first 2.0 launch
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

    // MARK: - Pure logic (unit-tested)

    /// A pre-2.0 user — recognised by any marker a 1.x launch leaves behind — qualifies as an
    /// early adopter eligible for the discount.
    static func isExistingPreV2User(rcApplied: Bool, grandfatherChecked: Bool, firstRunUpsellShown: Bool, ownsAnyProduct: Bool) -> Bool {
        rcApplied || grandfatherChecked || firstRunUpsellShown || ownsAnyProduct
    }

    /// `[start, start + duration)` — inclusive of the start instant, exclusive of the end.
    static func isWithinWindow(now: Date, start: Date, duration: TimeInterval = windowDuration) -> Bool {
        let elapsed = now.timeIntervalSince(start)
        return elapsed >= 0 && elapsed < duration
    }

    /// Whether the discounted offer should be surfaced right now.
    static func isOfferActive(now: Date, startTimestamp: Double, eligibleUser: Bool, isProEntitled: Bool) -> Bool {
        guard eligibleUser, !isProEntitled, startTimestamp > 0 else { return false }
        return isWithinWindow(now: now, start: Date(timeIntervalSince1970: startTimestamp))
    }

    /// Whether to surface the in-app notifications pre-prompt (which gates the system permission
    /// dialog). Only for eligible users while the offer is still active, shown at most once, and
    /// never once the user has already decided notification authorization in Settings.
    static func shouldOfferUpdatesPrompt(eligibleUser: Bool, offerActive: Bool,
                                         alreadyAsked: Bool, authDetermined: Bool) -> Bool {
        eligibleUser && offerActive && !alreadyAsked && !authDetermined
    }

    // MARK: - Runtime (app target)

    /// Live offer state from the persisted window start + current entitlement.
    static var isCurrentlyActive: Bool {
        isOfferActive(now: Date(), startTimestamp: firstLaunchTS, eligibleUser: eligibleUser, isProEntitled: Monetization.isProEntitled)
    }

    /// Call once per launch. On the very first 2.0 launch it stamps the window start and decides
    /// eligibility. It no longer requests notification authorization or schedules anything — the
    /// in-app updates pre-prompt drives that later (see `requestUpdatesAuthorizationThenSchedule`),
    /// so the OS permission dialog is never triggered at launch.
    static func startIfNeeded() {
        guard !initialized else { return }
        initialized = true
        firstLaunchTS = Date().timeIntervalSince1970
        let defaults = UserDefaults.group
        eligibleUser = isExistingPreV2User(
            rcApplied: defaults.bool(forKey: Constants.rcApplied.rawValue),
            grandfatherChecked: defaults.bool(forKey: Constants.grandfatherCheckedV2.rawValue),
            firstRunUpsellShown: defaults.bool(forKey: Constants.firstRunUpsellShown.rawValue),
            ownsAnyProduct: Monetization.isProPurchased || !Monetization.ownedPackProductIDs.isEmpty
        )
        // No auth request / scheduling here anymore — the in-app updates pre-prompt drives it.
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
            body: NSLocalizedString("Thanks for being an early user — unlock every pack, the custom keyboard and more at half price. Limited time.", comment: "Early-bird reminder body"))
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
