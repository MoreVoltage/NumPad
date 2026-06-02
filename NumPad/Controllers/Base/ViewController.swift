//
//  ViewController.swift
//  NumPad
//
//  Created by Lasha Efremidze on 2/19/17.
//  Copyright © 2017 MoreVoltage. All rights reserved.
//

import UIKit
import RevealingSplashView

class ViewController: UIViewController {
    private var deepLinkObserver: NSObjectProtocol?

    lazy var splashView: RevealingSplashView = { [unowned self] in
        let image = #imageLiteral(resourceName: "hashtag")
        let view = RevealingSplashView(iconImage: image, iconInitialSize: image.size, backgroundColor: .primary)
        self.view.addSubview(view)
        return view
    }()
    
    lazy var tableView: HomeViewController = { [unowned self] in
        let viewController = HomeViewController.instantiate()
        self.add(viewController)
        viewController.view.edgesToSuperview()
        // Add a "Try Keyboard" demo input below the splash to let users experiment
        let demoField = UITextField()
        demoField.placeholder = NSLocalizedString("Try the NumPad keyboard here", comment: "Demo text field placeholder on the home screen")
        demoField.borderStyle = .roundedRect
        demoField.backgroundColor = .secondarySystemBackground
        self.view.addSubview(demoField)
        demoField.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            demoField.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 16),
            demoField.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -16),
            demoField.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            demoField.heightAnchor.constraint(equalToConstant: 44)
        ])
        // Add toolbar with a Done button to dismiss the keyboard in-app
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        let flex = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let done = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(dismissKeyboard))
        toolbar.items = [flex, done]
        demoField.inputAccessoryView = toolbar
        return viewController
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        interactiveNavigationBarHidden = true

        _ = tableView

        // Install the deep-link observer up front (not inside the splash completion) so a cold
        // launch via numpad:// — where didBecomeActive can fire before the splash finishes —
        // isn't missed. Also drain any URL already set during launch.
        deepLinkObserver = NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            self?.handlePendingDeepLink()
        }
        handlePendingDeepLink()

        splashView.startAnimation() { [weak self] in
            guard let self = self else { return }
            if !Keyboard.isKeyboardEnabled {
                self.show(InstructionsViewController.instantiate(), sender: self)
            }
            RemoteConfigManager.start()
            // Apply RC defaults to first-run experience once
            if UserDefaults.group.bool(forKey: Constants.rcApplied.rawValue) == false {
                KeyboardTheme.selected = RemoteConfigManager.shared.defaultTheme
                KeyboardType.selected = RemoteConfigManager.shared.defaultPack
                UserDefaults.group.set(true, forKey: Constants.rcApplied.rawValue)
                // Notify the keyboard extension of the RC-derived default theme/pack.
                SettingsSync.post()
            }
            self.handlePendingDeepLink()
        }
    }

    private func handlePendingDeepLink() {
        guard
            let appDelegate = UIApplication.shared.delegate as? AppDelegate,
            let url = appDelegate.pendingURL
        else { return }
        appDelegate.pendingURL = nil
        if url.host == "store-preview" {
            show(StoreViewController(), sender: self)
        }
    }

    deinit {
        if let observer = deepLinkObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
}
