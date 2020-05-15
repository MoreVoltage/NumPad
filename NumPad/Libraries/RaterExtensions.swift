//
//  RaterExtensions.swift
//  NumPad
//
//  Created by Lasha Efremidze on 5/14/20.
//  Copyright © 2020 MoreVoltage. All rights reserved.
//

import SwiftRater

extension SwiftRater {
    static func configure() {
        daysUntilPrompt = 7
        usesUntilPrompt = 10
        significantUsesUntilPrompt = 3
        daysBeforeReminding = 3
        showLaterButton = true
        showLog = true
        appLaunched()
    }
}
