//
//  HelpStudioViewController.swift
//  NumPad
//

import UIKit

final class HelpStudioViewController: StudioScreenViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("Help", comment: "Help Studio title")
        view.accessibilityIdentifier = "studio.help"

        let setup = studioRow(
            title: NSLocalizedString("Set up NumPad", comment: "Help Studio action"),
            subtitle: NSLocalizedString("Follow the steps to add the keyboard in Settings", comment: "Help Studio description"),
            symbol: "checklist"
        ) { [weak self] in
            self?.navigationController?.pushViewController(InstructionsViewController.instantiate(), animated: true)
        }
        setup.accessibilityIdentifier = "studio.help.setup"

        let guide = studioRow(
            title: NSLocalizedString("Using NumPad", comment: "Help Studio action"),
            subtitle: NSLocalizedString("Learn about packs, gestures, and calculator tools", comment: "Help Studio description"),
            symbol: "book"
        ) { [weak self] in
            self?.navigationController?.pushViewController(FeaturesGuideViewController(), animated: true)
        }
        guide.accessibilityIdentifier = "studio.help.guide"

        let privacy = studioRow(
            title: NSLocalizedString("Privacy & Full Access", comment: "Help Studio action"),
            subtitle: NSLocalizedString("Understand what Full Access enables", comment: "Help Studio description"),
            symbol: "hand.raised"
        ) { [weak self] in
            self?.navigationController?.pushViewController(PrivacyViewController(), animated: true)
        }
        privacy.accessibilityIdentifier = "studio.help.privacy"

        let restore = studioRow(
            title: NSLocalizedString("Restore purchases", comment: "Help Studio action"),
            subtitle: NSLocalizedString("Restore a previous NumPad purchase", comment: "Help Studio description"),
            symbol: "arrow.clockwise"
        ) { [weak self] in
            let store = StoreViewController()
            store.source = "help_restore"
            self?.navigationController?.pushViewController(store, animated: true)
        }
        restore.accessibilityIdentifier = "studio.help.restore"

        addSection(title: NSLocalizedString("HELP & SUPPORT", comment: "Help Studio section label"), rows: [setup, guide, privacy, restore])
    }
}
