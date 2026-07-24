//
//  SceneDelegate.swift
//  NumPad
//
//  UIScene lifecycle support for iOS 13+.
//  Window creation and deep-link handling are moved here from AppDelegate.
//
//  Both iPhone and iPad use the storyboard root (`ViewController`) so launch,
//  foreground, CloudSync, StoreKit, and deep-link orchestration stay shared.
//  On iPad, `ViewController` embeds `IPadSettingsSplitViewController` as its shell.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        window = UIWindow(windowScene: windowScene)
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        window?.rootViewController = storyboard.instantiateInitialViewController()
        window?.makeKeyAndVisible()

        // Handle deep-link if the app was launched via URL
        if let url = connectionOptions.urlContexts.first?.url {
            handleDeepLink(url)
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        handleDeepLink(url)
    }

    private func handleDeepLink(_ url: URL) {
        guard DeepLinkRouter.parse(url) != nil else { return }
        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            appDelegate.pendingURL = url
        }
        // If the root lifecycle coordinator is already alive, drain immediately so cold-launch
        // URLs aren't stuck waiting for the next didBecomeActive.
        if let root = window?.rootViewController {
            _ = DeepLinkRouter.drainPending(from: root)
        }
    }
}
