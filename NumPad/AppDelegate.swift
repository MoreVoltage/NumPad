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

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    // Window creation lives in SceneDelegate under the UIScene lifecycle.
    var pendingURL: URL?
    private let managedProfileCoordinator = ManagedProfileCoordinator()
    private var entitlementObserver: NSObjectProtocol?
    
    override init() {
        super.init()
        
        UIViewController.classInit
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        #if DEBUG
        // XCUITest app-group state can outlive a simulator reinstall. Reset before any startup
        // migration, entitlement, management, or Cloud Sync work can observe stale values.
        DeepLinkRouter.applyUITestAppGroupResetIfRequested()
        #endif
        Analytics.start
        // Configure Remote Config here (process launch), not only from ViewController.finishLaunch()
        // (scene/window launch): App Intents (Siri/Shortcuts/Spotlight — see NumPadShortcuts) run
        // with openAppWhenRun == false, so the process launches and this fires, but no UIScene/window
        // is ever created and ViewController.viewDidLoad() never runs. Without this, RC.configureDefaults()
        // never runs for a headless intent launch, so RemoteConfig.boolValue reads (e.g.
        // RemoteConfigManager.shared.appIntentsEnabled) return the unconfigured default of false and
        // every intent perform() throws NumPadIntentError.disabled. See CLAUDE.md/moonshot review notes.
        RemoteConfigManager.start()
        KeyboardProfileMigration.runIfNeeded()
        managedProfileCoordinator.applyCurrentConfiguration()
        entitlementObserver = NotificationCenter.default.addObserver(
            forName: StoreManager.entitlementsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.managedProfileCoordinator.applyCurrentConfiguration()
        }
        CloudSyncProfiles.install()
        Theme.configure()
        SwiftRater.configure()
        SettingsBundle.update()
        return true
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        Analytics.logEvent(name: "session", attributes: ["reversed_mode": Keyboard.isReversedMode, "rounded_corners": Keyboard.hasRoundedCorners, "grid": Keyboard.hasGrid, "keyboard_type": KeyboardType.selected.rawValue, "keyboard_theme": KeyboardTheme.selected.rawValue, "automatic_dark_mode": KeyboardTheme.automaticDarkMode])
        SessionMilestone.recordSession()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        managedProfileCoordinator.applyCurrentConfiguration()
    }

    // MARK: - UIScene support

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }

    // Legacy deep-link handler (pre-scene lifecycle fallback)
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        if DeepLinkRouter.parse(url) != nil {
            self.pendingURL = url
            return true
        }
        return false
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
            let navAppearance = UINavigationBarAppearance()
            navAppearance.configureWithOpaqueBackground()
            navAppearance.backgroundColor = .primary
            navAppearance.shadowColor = nil
            navAppearance.titleTextAttributes = [.foregroundColor: UIColor.white, .font: UIFont.preferredFont(for: .body, weight: .bold)]
            UINavigationBar.appearance().standardAppearance = navAppearance
            UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
            UINavigationBar.appearance().compactAppearance = navAppearance
            UINavigationBar.appearance().tintColor = .white
            UISwitch.appearance().onTintColor = .primary
        }
    }
}
