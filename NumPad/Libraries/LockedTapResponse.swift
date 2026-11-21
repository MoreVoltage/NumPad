//
//  LockedTapResponse.swift
//  NumPad / Keyboard
//
//  Shared (both targets). What the keyboard does when the user taps something locked behind the
//  paywall (a locked key, a locked pack in the pack picker, a locked conversion category).
//
//  App Review guideline 4.4.1: keyboard extensions may not launch other apps besides Settings.
//  So a locked tap never opens NumPad. It counts the tap for the lock funnel and shows a short,
//  non-blocking hint telling the user where to unlock it. `storeDeeplinkOpens` is never bumped
//  here, because no deep link is attempted.
//

import Foundation

/// Where a locked tap came from. Kept for clarity at the call sites; the extension logs no
/// analytics, so the source is not recorded anywhere.
enum LockedTapSource: CaseIterable {
    case keyLock
    case packPicker
    case conversionLock
}

/// Shows the transient "unlock in the app" hint. Implemented by the keyboard view controller.
protocol LockedTapHintPresenting: AnyObject {
    func showLockedTapHint(_ message: String)
}

enum LockedTapResponse {
    /// How long the hint stays up before fading. Short so it never blocks typing.
    static let hintDisplayDuration: TimeInterval = 2.5

    static var hintMessage: String {
        NSLocalizedString("Open the NumPad app to unlock this.",
                          comment: "Keyboard: brief hint shown after tapping a locked key, pack or conversion")
    }

    static func handle(source: LockedTapSource, presenter: LockedTapHintPresenting) {
        LockFunnelCounters.incrementLockedKeyTaps()
        presenter.showLockedTapHint(hintMessage)
    }
}
