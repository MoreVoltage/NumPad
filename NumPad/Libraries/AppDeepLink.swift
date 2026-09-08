//
//  AppDeepLink.swift
//  NumPad
//
//  Release (not DEBUG-only) `numpad://` routes. Debug routes stay on `DebugDeepLinkRoute`.
//

import Foundation

enum AppDeepLink: Equatable {
    case storePreview(source: String?)
    case whatsNew
    case appStore

    static func parse(_ url: URL) -> AppDeepLink? {
        guard url.scheme == "numpad" else { return nil }
        switch url.host {
        case "store-preview":
            let source = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first { $0.name == "source" }?.value
            return .storePreview(source: source)
        case "app-store":
            return .appStore
        case "whats-new":
            return .whatsNew
        default:
            return nil
        }
    }
}

extension Notification.Name {
    /// Posted after a notification tap (or similar) writes `AppDelegate.pendingURL`, so the
    /// root VC can drain it without waiting for the next `didBecomeActive`.
    static let numpadPendingDeepLink = Notification.Name("com.morevoltage.numpad.pendingDeepLink")
}
