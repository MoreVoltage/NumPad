//
//  HelpStudioViewController.swift
//  NumPad
//

import UIKit
import SwiftRater

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

        let status = studioRow(
            title: NSLocalizedString("Setup status", comment: "Help Studio action"),
            subtitle: Keyboard.isKeyboardEnabled
                ? NSLocalizedString("NumPad is ready to use", comment: "Help setup readiness")
                : NSLocalizedString("NumPad still needs to be enabled in Settings", comment: "Help setup readiness"),
            symbol: Keyboard.isKeyboardEnabled ? "checkmark.circle" : "exclamationmark.triangle"
        ) { [weak self] in
            self?.navigationController?.pushViewController(InstructionsViewController.instantiate(), animated: true)
        }
        status.accessibilityIdentifier = "studio.help.status"

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

        let feedback = studioRow(
            title: NSLocalizedString("Send feedback", comment: "Help Studio action"),
            subtitle: NSLocalizedString("Tell us what would make NumPad better", comment: "Help Studio description"),
            symbol: "envelope"
        ) {
            UIApplication.shared.open(URL(string: "mailto:support@morevoltage.com?subject=NumPad%20Feedback")!)
            Analytics.logEvent(name: "send_feedback", attributes: ["source": "studio_help"])
        }
        feedback.accessibilityIdentifier = "studio.help.feedback"
        let rate = studioRow(
            title: NSLocalizedString("Rate NumPad", comment: "Help Studio action"),
            subtitle: NSLocalizedString("Share your experience on the App Store", comment: "Help Studio description"),
            symbol: "star"
        ) { [weak self] in
            guard let self else { return }
            SwiftRater.rateApp(host: self)
            Analytics.logEvent(name: "rate", attributes: ["source": "studio_help"])
        }
        rate.accessibilityIdentifier = "studio.help.rate"
        let policy = studioRow(
            title: NSLocalizedString("Privacy policy", comment: "Help Studio action"),
            subtitle: NSLocalizedString("Read our privacy policy in Safari", comment: "Help Studio description"),
            symbol: "doc.text"
        ) { UIApplication.shared.open(URL(string: "https://morevoltage.com/numpad/privacy")!) }
        policy.accessibilityIdentifier = "studio.help.policy"
        let version = StudioRowView(
            title: NSLocalizedString("Version", comment: "Help Studio version"),
            subtitle: Bundle.main.version ?? NSLocalizedString("Unavailable", comment: "Unavailable version"),
            symbolName: "info.circle", accessory: .disclosure, palette: palette
        )
        version.accessibilityIdentifier = "studio.help.version"
        version.accessibilityHint = NSLocalizedString("Open version and release details", comment: "Help version action accessibility hint")
        version.onTap = { [weak self] in self?.showVersionDetails() }

        addSection(title: NSLocalizedString("SETUP", comment: "Help Studio section label"), rows: [status, setup])
        addSection(title: NSLocalizedString("USING NUMPAD", comment: "Help Studio section label"), rows: [guide, privacy])
        addSection(title: NSLocalizedString("SUPPORT", comment: "Help Studio section label"), rows: [feedback, rate, restore, policy, version])
    }

    private func showVersionDetails() {
        let version = Bundle.main.version ?? NSLocalizedString("Unavailable", comment: "Unavailable version")
        let alert = UIAlertController(
            title: NSLocalizedString("NumPad version", comment: "Help version details title"),
            message: String(
                format: NSLocalizedString("Version %@. See the App Store listing for the latest release notes.", comment: "Help version details message"),
                version
            ),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Dismiss version details"), style: .default))
        present(alert, animated: true)
    }
}
