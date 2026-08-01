//
//  StudioTabBarController.swift
//  NumPad
//

import UIKit
import SwiftRater

/// The compact-width Keyboard Studio information architecture. Every visible destination is
/// navigation-wrapped so legacy deep links can continue to push from the selected tab.
final class StudioTabBarController: UITabBarController {
    override func viewDidLoad() {
        super.viewDidLoad()
        tabBar.accessibilityIdentifier = "studio.tab-bar"
        tabBar.tintColor = StudioTheme.standard.accentFilled
        tabBar.backgroundColor = StudioTheme.standard.surfaceElevated
    }

    /// Live Studio root after the 2026-07-29 migration. The only other `SwiftRater.check()`
    /// call site is orphaned `HomeViewController` — without this, the automatic prompt never runs.
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        SwiftRater.check()
    }
}
