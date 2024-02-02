//
//  AppDelegate.swift
//  NumPad
//
//  Created by Lasha Efremidze on 2/19/17.
//  Copyright © 2017 MoreVoltage. All rights reserved.
//

import UIKit
import SwiftRater
import FirebasePerformance

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    
    override init() {
        super.init()
        
        UIViewController.classInit
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        Analytics.start
        Theme.configure()
        SwiftRater.configure()
        SettingsBundle.update()
        return true
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        Analytics.logEvent(name: "session", attributes: ["reversed_mode": Keyboard.isReversedMode, "rounded_corners": Keyboard.hasRoundedCorners, "grid": Keyboard.hasGrid, "keyboard_type": KeyboardType.selected.rawValue, "keyboard_theme": KeyboardTheme.selected.rawValue, "automatic_dark_mode": KeyboardTheme.automaticDarkMode])
    }
    
}

extension AppDelegate {
    struct SettingsBundle {
        static func update() {
            UserDefaults.standard.set(Bundle.main.version, forKey: "Version")
            UserDefaults.standard.set(Bundle.main.build, forKey: "Build")
        }
    }
    struct Theme {
        static func configure() {
            UINavigationBar.appearance().setBackgroundImage(UIColor.primary.image(), for: .default)
            UINavigationBar.appearance().shadowImage = UIImage()
            UINavigationBar.appearance().tintColor = .white
            UINavigationBar.appearance().titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white, NSAttributedString.Key.font: UIFont.preferredFont(for: .body, weight: .bold)]
            UISwitch.appearance().onTintColor = .primary
        }
    }
}
