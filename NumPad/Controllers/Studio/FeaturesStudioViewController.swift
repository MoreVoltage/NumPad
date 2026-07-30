//
//  FeaturesStudioViewController.swift
//  NumPad
//

import UIKit

final class FeaturesStudioViewController: StudioScreenViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("Features", comment: "Features Studio title")
        view.accessibilityIdentifier = "studio.features"

        let calculator = studioRow(
            title: NSLocalizedString("Calculator tools", comment: "Features Studio action"),
            subtitle: NSLocalizedString("Live answers, result tape, and tax or tip help", comment: "Features Studio description"),
            symbol: "function"
        ) { [weak self] in
            self?.navigationController?.pushViewController(TypingBehaviorViewController(), animated: true)
        }
        calculator.accessibilityIdentifier = "studio.features.calculator"

        let reusableText = studioRow(
            title: NSLocalizedString("Reusable text", comment: "Features Studio action"),
            subtitle: NSLocalizedString("Snippets and clipboard history you can insert from the keyboard", comment: "Features Studio description"),
            symbol: "text.badge.plus"
        ) { [weak self] in
            self?.navigationController?.pushViewController(SnippetsViewController(), animated: true)
        }
        reusableText.accessibilityIdentifier = "studio.features.reusable-text"

        let fullAccess = studioRow(
            title: NSLocalizedString("About Full Access", comment: "Features Studio action"),
            subtitle: NSLocalizedString("Learn what clipboard history, vibration, and sounds need", comment: "Features Studio description"),
            symbol: "hand.raised"
        ) { [weak self] in
            self?.navigationController?.pushViewController(PrivacyViewController(), animated: true)
        }
        fullAccess.accessibilityIdentifier = "studio.features.full-access"

        let customKeys = studioRow(
            title: NSLocalizedString("Custom keys", comment: "Features Studio action"),
            subtitle: NSLocalizedString("Create a keyboard layout that fits your work", comment: "Features Studio description"),
            symbol: "keyboard.badge.ellipsis"
        ) { [weak self] in
            guard let self else { return }
            guard Monetization.isCustomKeyboardEntitled else {
                let store = StoreViewController()
                store.source = "studio_features_custom_keys"
                self.show(store, sender: self)
                return
            }
            self.navigationController?.pushViewController(CustomKeyboardEditorViewController(), animated: true)
        }
        customKeys.accessibilityIdentifier = "studio.features.custom-keys"
        customKeys.setAccessory(Monetization.isCustomKeyboardEntitled ? .disclosure : .locked(NSLocalizedString("Pro", comment: "Features custom keys lock")))

        addSection(title: NSLocalizedString("CALCULATOR TOOLS", comment: "Features Studio section label"), rows: [calculator])
        addSection(title: NSLocalizedString("REUSABLE TEXT", comment: "Features Studio section label"), rows: [reusableText, fullAccess])
        addSection(title: NSLocalizedString("CUSTOM KEYS", comment: "Features Studio section label"), rows: [customKeys])
    }
}
