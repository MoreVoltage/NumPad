//
//  WhatsNewNotification.swift
//  NumPad
//
//  One timed local notification after the 2.0.3 What's New grant. App target only — the
//  keyboard never schedules notifications (same rule as EarlyBird). Identifier is not an
//  EarlyBird reminder id.
//

import Foundation
import UserNotifications
import UIKit

protocol WhatsNewNotificationScheduling: AnyObject {
    func add(_ request: UNNotificationRequest, withCompletionHandler completionHandler: ((Error?) -> Void)?)
}

extension UNUserNotificationCenter: WhatsNewNotificationScheduling {}

enum WhatsNewNotification {
    static let requestID = "numpad.whatsnew.once"
    static let delay: TimeInterval = 24 * 3600
    static let authorizationOptions: UNAuthorizationOptions = [.alert, .sound, .provisional]

    static func makeRequest(granted: Bool, alreadyScheduled: Bool) -> UNNotificationRequest? {
        guard granted, !alreadyScheduled else { return nil }
        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("NumPad", comment: "2.0.3 What's New local notification title")
        content.body = NSLocalizedString(
            "NumPad is ready when you need numbers. Open the app if you want the recap again.",
            comment: "2.0.3 What's New local notification body"
        )
        content.sound = .default
        content.userInfo = ["deeplink": WhatsNew.deepLinkURLString]
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        return UNNotificationRequest(identifier: requestID, content: content, trigger: trigger)
    }

    /// Adds at most one request. Returns the resulting `alreadyScheduled` flag (true after a
    /// successful add, unchanged when denied or already scheduled). Never uses EarlyBird ids.
    @discardableResult
    static func addRequestIfNeeded(granted: Bool, alreadyScheduled: Bool,
                                   center: WhatsNewNotificationScheduling) -> Bool {
        guard let request = makeRequest(granted: granted, alreadyScheduled: alreadyScheduled) else {
            return alreadyScheduled
        }
        center.add(request, withCompletionHandler: nil)
        return true
    }

    static func scheduleIfGranted(_ granted: Bool) {
        let scheduled = addRequestIfNeeded(
            granted: granted,
            alreadyScheduled: WhatsNew.notificationScheduled,
            center: UNUserNotificationCenter.current()
        )
        WhatsNew.notificationScheduled = scheduled
    }

    static func requestAuthorizationThenSchedule() {
        UNUserNotificationCenter.current().requestAuthorization(options: authorizationOptions) { granted, _ in
            DispatchQueue.main.async {
                scheduleIfGranted(granted)
            }
        }
    }
}

/// One delegate handles existing local recap reminders and remote update campaigns.
final class WhatsNewNotificationTapHandler: NSObject, UNUserNotificationCenterDelegate {
    static let shared = WhatsNewNotificationTapHandler()
    private var lastResponse: String?

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        handle(response)
        completionHandler()
    }

    /// UIScene supplies the response here on a cold launch; the notification-center delegate
    /// handles warm launches. Deduplicate the same response if iOS supplies both callbacks.
    func handle(_ response: UNNotificationResponse) {
        guard response.actionIdentifier == UNNotificationDefaultActionIdentifier else { return }
        let request = response.notification.request
        guard let url = UpdateNotificationPolicy.destination(identifier: request.identifier,
            userInfo: request.content.userInfo) else { return }
        let identity = request.identifier + "|" + String(response.notification.date.timeIntervalSince1970)
        DispatchQueue.main.async { [weak self] in
            guard let self, self.lastResponse != identity,
                  let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
            self.lastResponse = identity
            appDelegate.pendingURL = url
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let content = notification.request.content
        DispatchQueue.main.async {
            let show = UpdateNotifications.isEnabled
                && content.userInfo["kind"] as? String == "numpad_update"
                && UpdateNotificationPolicy.destination(identifier: notification.request.identifier,
                    userInfo: content.userInfo) != nil
            completionHandler(show ? [.banner, .list, .sound] : [])
        }
    }
}
