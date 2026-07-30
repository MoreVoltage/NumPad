//
//  StudioTabBarController.swift
//  NumPad
//

import UIKit

/// The compact-width Keyboard Studio information architecture. Every visible destination is
/// navigation-wrapped so legacy deep links can continue to push from the selected tab.
final class StudioTabBarController: UITabBarController {
    override func viewDidLoad() {
        super.viewDidLoad()
        tabBar.accessibilityIdentifier = "studio.tab-bar"
        tabBar.tintColor = StudioTheme.standard.accentFilled
        tabBar.backgroundColor = StudioTheme.standard.surfaceElevated
    }
}
