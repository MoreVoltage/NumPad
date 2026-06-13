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
    /// The first foreground is handled by `StoreManager.start()` (cold launch); only *subsequent*
    /// activations trigger a downgrade-capable entitlement refresh.
    private var hasBecomeActiveOnce = false
    /// Bottom constraint of the demo field; its constant is adjusted to keep the field
    /// visible above the keyboard (any keyboard — NumPad or system, which differ in height).
    private var demoFieldBottomConstraint: NSLayoutConstraint?
    private let demoFieldBottomInset: CGFloat = 16

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
        let bottom = demoField.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor, constant: -demoFieldBottomInset)
        self.demoFieldBottomConstraint = bottom
        NSLayoutConstraint.activate([
            demoField.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 16),
            demoField.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -16),
            bottom,
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
            guard let self = self else { return }
            self.handlePendingDeepLink()
            // Re-verify entitlements on every foreground after the first, so refunds/revocations
            // (and any tampered group flag) are corrected promptly while StoreKit is ready.
            if self.hasBecomeActiveOnce {
                StoreManager.refreshEntitlementsOnForeground()
            }
            self.hasBecomeActiveOnce = true
        }
        handlePendingDeepLink()

        // Keyboard avoidance for the demo field. willChangeFrame (not just willShow) also fires
        // when the user switches keyboards (NumPad ↔ system — different heights) and on rotation,
        // so the field tracks every height change. willHide restores the resting position.
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChangeFrame(_:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)

        // Respect Reduce Motion: skip the splash zoom/reveal animation and go straight to content.
        if UIAccessibility.isReduceMotionEnabled {
            splashView.removeFromSuperview()
            finishLaunch()
        } else {
            splashView.startAnimation() { [weak self] in
                self?.finishLaunch()
            }
        }
    }

    /// Post-splash launch work: onboarding, RC/Store start, first-run defaults, and deep-link drain.
    private func finishLaunch() {
        if !Keyboard.isKeyboardEnabled {
            self.show(InstructionsViewController.instantiate(), sender: self)
        }
        RemoteConfigManager.start()
        StoreManager.start()
        SnippetsManager.shared.pullFromCloudIfEnabled()
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
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    // MARK: - Keyboard avoidance

    @objc private func keyboardWillChangeFrame(_ notification: Notification) {
        guard
            let userInfo = notification.userInfo,
            let endFrame = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
        else { return }
        // Convert the keyboard frame into this view's coordinate space, then measure the
        // overlap with our bounds. During an interactive dismiss or when the keyboard is
        // off-screen the overlap is zero and the field returns to its resting position.
        let endFrameInView = view.convert(endFrame, from: view.window)
        let overlap = max(0, view.bounds.maxY - endFrameInView.minY)
        // The bottom constraint is relative to the safe area; subtract the bottom safe-area
        // inset that's already accounted for so the field sits `demoFieldBottomInset` above
        // the keyboard, not double-offset on home-indicator devices.
        let safeBottom = view.safeAreaInsets.bottom
        let adjusted = max(0, overlap - safeBottom)
        applyDemoFieldOffset(-(demoFieldBottomInset + adjusted), userInfo: userInfo)
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        applyDemoFieldOffset(-demoFieldBottomInset, userInfo: notification.userInfo)
    }

    private func applyDemoFieldOffset(_ constant: CGFloat, userInfo: [AnyHashable: Any]?) {
        guard let constraint = demoFieldBottomConstraint, constraint.constant != constant else { return }
        constraint.constant = constant
        let duration = (userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval) ?? 0.25
        let curveRaw = (userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? Int) ?? UIView.AnimationCurve.easeInOut.rawValue
        let options = UIView.AnimationOptions(rawValue: UInt(curveRaw) << 16)
        UIView.animate(withDuration: duration, delay: 0, options: [options, .beginFromCurrentState], animations: {
            self.view.layoutIfNeeded()
        })
        // Keep the settings list scrollable above the raised field. On iOS 15+ UIScrollView
        // already insets itself for the keyboard automatically; we only add the demo field's
        // own height + padding on top of that while the keyboard is up.
        let fieldExtra: CGFloat = constant == -demoFieldBottomInset ? 0 : 44 + demoFieldBottomInset
        tableView.tableView.contentInset.bottom = fieldExtra
        tableView.tableView.verticalScrollIndicatorInsets.bottom = fieldExtra
    }

}
