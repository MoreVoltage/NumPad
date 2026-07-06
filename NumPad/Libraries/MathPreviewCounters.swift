//
//  MathPreviewCounters.swift
//  NumPad / Keyboard
//
//  Shared (both targets). O(1), allocation-free counters the keyboard extension bumps for the Live
//  Math Preview funnel, since the extension has no Firebase. Mirrors LockFunnelCounters exactly:
//  the app reads + zeroes them on every foreground and logs a single aggregated
//  `math_preview_engagement` analytics event when any counter is non-zero, so a burst of extension
//  activity is never reported more than once.
//
//  `shown` is intentionally throttled by the caller to once per keyboard appearance (see
//  `KeyboardViewController.mathPreviewShownLoggedThisAppearance`) rather than once per render —
//  the chip can redraw many times a second while typing, and a per-render count would be noise.
//  `inserted` counts a real, discrete user action, so it increments on every tap.
//

import Foundation

enum MathPreviewCounters {
    @UserDefault(key: Constants.mathPreviewShown.rawValue, defaultValue: 0, userDefaults: .group)
    static var shown: Int
    @UserDefault(key: Constants.mathPreviewInserted.rawValue, defaultValue: 0, userDefaults: .group)
    static var inserted: Int

    // MARK: - Extension side (increment only; called from the keyboard's UI/tap handling)

    static func incrementShown() { shown += 1 }
    static func incrementInserted() { inserted += 1 }

    // MARK: - App side (read + flush)

    /// A point-in-time read of the two counters — pure and unit-testable without touching
    /// UserDefaults.
    struct Snapshot: Equatable {
        let shown: Int
        let inserted: Int

        var hasActivity: Bool { shown > 0 || inserted > 0 }
        var analyticsAttributes: [String: Any] {
            ["math_preview_shown": shown, "math_preview_inserted": inserted]
        }
    }

    /// Call once per app foreground, alongside `LockFunnelCounters.flushIfNeeded()`. Logs one
    /// aggregated event when any counter is non-zero, then drains exactly the amounts just read —
    /// subtracting (not zeroing outright) so a concurrent extension-side increment between the read
    /// and the write below isn't silently lost (same race as LockFunnelCounters; see its doc).
    static func flushIfNeeded() {
        let snapshot = Snapshot(shown: shown, inserted: inserted)
        guard snapshot.hasActivity else { return }
        Analytics.logEvent(name: "math_preview_engagement", attributes: snapshot.analyticsAttributes)
        shown -= snapshot.shown
        inserted -= snapshot.inserted
    }
}
