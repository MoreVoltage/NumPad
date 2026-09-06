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

/// Handles a tap on `numpad.whatsnew.once` by opening the recap. Does not handle EarlyBird ids.
final class WhatsNewNotificationTapHandler: NSObject, UNUserNotificationCenterDelegate {
    static let shared = WhatsNewNotificationTapHandler()

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.notification.request.identifier == WhatsNewNotification.requestID,
           let url = URL(string: WhatsNew.deepLinkURLString),
           let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            appDelegate.pendingURL = url
            NotificationCenter.default.post(name: .numpadPendingDeepLink, object: nil)
        }
        completionHandler()
    }
}
