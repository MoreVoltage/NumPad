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
            subtitle: NSLocalizedString("Manage snippets you can insert from the keyboard", comment: "Features Studio description"),
            symbol: "text.badge.plus"
        ) { [weak self] in
            self?.navigationController?.pushViewController(SnippetsViewController(), animated: true)
        }
        reusableText.accessibilityIdentifier = "studio.features.reusable-text"

        let customKeys = studioRow(
            title: NSLocalizedString("Custom keys", comment: "Features Studio action"),
            subtitle: NSLocalizedString("Create a keyboard layout that fits your work", comment: "Features Studio description"),
            symbol: "keyboard.badge.ellipsis"
        ) { [weak self] in
            self?.navigationController?.pushViewController(CustomKeyboardEditorViewController(), animated: true)
        }
        customKeys.accessibilityIdentifier = "studio.features.custom-keys"

        addSection(title: NSLocalizedString("MAKE NUMPAD YOURS", comment: "Features Studio section label"), rows: [calculator, reusableText, customKeys])
    }
}
