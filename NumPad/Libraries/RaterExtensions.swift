//
//  RaterExtensions.swift
//  NumPad
//
//  Created by Lasha Efremidze on 5/14/20.
//  Copyright © 2020 MoreVoltage. All rights reserved.
//

import SwiftRater

extension SwiftRater {
    /// Configures the automatic App Store rating prompt.
    ///
    /// History: thresholds were set (7 days / 10 launches / 3 significant uses) but
    /// `incrementSignificantUsageCount` was never called anywhere in the app target.
    /// With `conditionsMetMode == .all`, that made `ratingConditionsHaveBeenMet`
    /// permanently false — so `SwiftRater.check()` could never prompt. Manual
    /// `rateApp(host:)` still worked because it forces the alert.
    ///
    /// Fix: require days + launches only. Significant-use counting is not wired, so set
    /// the threshold to **0** (always met), not **-1**. In SwiftRater 2.2.2, `-1` is
    /// `SwiftRaterInvalid` and *skips* the assignment, leaving `significantUsesUntilPromptMet`
    /// at its `false` default — which still permanently blocks `.all` mode.
    /// Call `SwiftRater.check()` from live Studio roots (not only orphaned Home).
    static func configure() {
        daysUntilPrompt = 7
        usesUntilPrompt = 10
        // 0 ≠ SwiftRaterInvalid → gate runs as `significantEventCount >= 0` → always true.
        // Do NOT set -1; that is the library's "unset" sentinel and leaves the flag false.
        significantUsesUntilPrompt = 0
        daysBeforeReminding = 3
        conditionsMetMode = .all
        showLaterButton = true
        showLog = false
        #if DEBUG
        // Keep production behavior in debug so we do not ship "always prompt" by habit.
        debugMode = false
        #endif
        appLaunched()
    }
}
