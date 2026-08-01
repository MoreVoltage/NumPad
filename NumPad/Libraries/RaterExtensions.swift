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
    /// Fix: require days + launches only (leave significant-use gate unset), keep
    /// a short "remind later" window, and prefer the native StoreKit prompt path.
    static func configure() {
        daysUntilPrompt = 7
        usesUntilPrompt = 10
        // Unset: significant-use counting is not wired in the product. Re-enable only
        // after call sites increment on real value moments (e.g. keyboard enabled).
        significantUsesUntilPrompt = -1
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
