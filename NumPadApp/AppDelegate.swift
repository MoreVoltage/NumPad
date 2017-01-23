//
//  AppDelegate.swift
//  NumPadApp
//
//  Created by Lasha Efremidze on 1/17/16.
//  Copyright © 2016 Lasha Efremidze. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        UINavigationBar.appearance().setBackgroundImage(UIImage(), for: .default)
        UINavigationBar.appearance().shadowImage = UIImage()
        UINavigationBar.appearance().titleTextAttributes = [NSFontAttributeName: UIFont(name: "SFUIDisplay-Bold", size: 18)!]
        return true
    }
    
}
