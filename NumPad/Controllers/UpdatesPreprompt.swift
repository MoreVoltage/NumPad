//
//  UpdatesPreprompt.swift
//  NumPad
//
//  In-app "soft ask" shown before the system notification permission dialog. It explains the value
//  of updates so the user opts in deliberately; only on "Turn on updates" do we trigger the real OS
//  prompt. Shown at most once, and only to early-bird-active users who haven't already decided
//  notification authorization in Settings. App target only (the keyboard never schedules anything).
//

import UIKit
import UserNotifications

enum UpdatesPreprompt {
    /// Show the in-app updates pre-prompt from `presenter` if (and only if) the early-bird gate
    /// passes. Cheap synchronous checks short-circuit first so we don't even query the OS auth
    /// status when it would be pointless; the OS status is then read asynchronously and the final
    /// decision is delegated to the unit-tested `EarlyBird.shouldOfferUpdatesPrompt` pure function.
    static func presentIfNeeded(from presenter: UIViewController) {
        let defaults = UserDefaults.group
        // Already asked once — never nag again (the in-app countdown still drives the offer).
        guard defaults.bool(forKey: Constants.updatesPrepromptShown.rawValue) == false else { return }
        // `isCurrentlyActive` == eligible pre-2.0 user (startTimestamp > 0) AND inside the 72h
        // window AND not Pro, i.e. the runtime stand-in for "eligible user + offer active". It's a
        // computed property doing a live Date()/entitlement check, so capture it ONCE here and reuse
        // that single value across the async boundary (two live reads could otherwise disagree). If
        // it's false, there's nothing to offer, so skip even reading the OS auth status.
        let isEligibleAndActive = EarlyBird.isCurrentlyActive
        guard isEligibleAndActive else { return }

        // Read the OS authorization status off the main thread, then decide.
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let authDetermined = settings.authorizationStatus != .notDetermined
            // Single decision point: the two pre-collapsed inputs (eligibleUser/offerActive) were
            // both confirmed true above via the captured `isEligibleAndActive`, and `alreadyAsked`
            // was confirmed false; we pass those constants so the tested boolean stays the only
            // authority.
            let shouldOffer = EarlyBird.shouldOfferUpdatesPrompt(
                eligibleUser: isEligibleAndActive,  // captured eligible+active, checked true above
                offerActive: true,
                alreadyAsked: false,                // already checked false above
                authDetermined: authDetermined)
            guard shouldOffer else { return }

            DispatchQueue.main.async {
                // Another modal (e.g. the first-run upsell) may have taken the screen between our
                // async auth-status read and now — bail without consuming the one-shot flag so we
                // cleanly retry on a later foreground.
                guard presenter.presentedViewController == nil else { return }
                presentAlert(from: presenter)
            }
        }
    }

    /// Build and present the soft-ask alert. A plain `.alert` needs no popover anchor, so it's safe
    /// on iPad without configuring `popoverPresentationController`.
    private static func presentAlert(from presenter: UIViewController) {
        let alert = UIAlertController(
            title: NSLocalizedString("Stay in the loop", comment: "Updates notification pre-prompt title"),
            message: NSLocalizedString(
                "NumPad can send occasional notifications about new features and important updates — and the rare early-bird offer. No spam, ever.",
                comment: "Updates notification pre-prompt message explaining what notifications are for"),
            preferredStyle: .alert)

        // "Not now": consume the one-shot flag so the pre-prompt never nags again. The in-app
        // countdown still surfaces the offer without notifications.
        alert.addAction(UIAlertAction(
            title: NSLocalizedString("Not now", comment: "Updates pre-prompt decline button"),
            style: .cancel,
            handler: { _ in
                UserDefaults.group.set(true, forKey: Constants.updatesPrepromptShown.rawValue)
            }))

        // "Turn on updates": consume the one-shot flag, then trigger the real OS permission dialog
        // (and schedule the early-bird reminders on grant).
        alert.addAction(UIAlertAction(
            title: NSLocalizedString("Turn on updates", comment: "Updates pre-prompt opt-in button"),
            style: .default,
            handler: { _ in
                UserDefaults.group.set(true, forKey: Constants.updatesPrepromptShown.rawValue)
                EarlyBird.requestUpdatesAuthorizationThenSchedule()
            }))

        presenter.present(alert, animated: true)
    }
}
