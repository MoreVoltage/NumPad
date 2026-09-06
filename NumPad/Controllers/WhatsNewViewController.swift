//
//  WhatsNewViewController.swift
//  NumPad
//
//  One-time 2.0.3 recap sheet. Not a paywall, not onboarding, not UpdatesPreprompt.
//

import UIKit
import UserNotifications

final class WhatsNewViewController: UIViewController {
    /// Auto-present once when the gate passes and nothing else is covering the home screen.
    static func presentIfNeeded(from presenter: UIViewController) {
        let navShowingOther = presenter.navigationController.map { $0.topViewController !== presenter } ?? false
        guard WhatsNew.canPresent(hasModal: presenter.presentedViewController != nil,
                                  navShowingOtherScreen: navShowingOther) else { return }
        guard WhatsNew.shouldPresent(lastSeen: WhatsNew.lastSeenVersion, current: WhatsNew.currentVersion) else { return }
        present(from: presenter, force: false)
    }

    /// `force` is the deep-link / notification-tap recap, including after the one-shot is consumed.
    static func present(from presenter: UIViewController, force: Bool) {
        if !force {
            let navShowingOther = presenter.navigationController.map { $0.topViewController !== presenter } ?? false
            guard WhatsNew.canPresent(hasModal: presenter.presentedViewController != nil,
                                      navShowingOtherScreen: navShowingOther) else { return }
        } else if presenter.presentedViewController != nil {
            return
        }
        let sheet = WhatsNewViewController()
        sheet.modalPresentationStyle = .pageSheet
        if let detents = sheet.sheetPresentationController {
            detents.detents = [.medium(), .large()]
            detents.prefersGrabberVisible = true
        }
        WhatsNew.markSeen()
        presenter.present(sheet, animated: !UIAccessibility.isReduceMotionEnabled)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = NSLocalizedString("What's New", comment: "2.0.3 What's New sheet title")

        let titleLabel = UILabel()
        titleLabel.text = NSLocalizedString("What's New in 2.0.3", comment: "2.0.3 What's New sheet heading")
        titleLabel.font = .preferredFont(forTextStyle: .title2)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.numberOfLines = 0

        let bodyLabel = UILabel()
        bodyLabel.text = NSLocalizedString(
            "Open NumPad once after this update to see what's new and turn on a single reminder for future updates.",
            comment: "2.0.3 What's New sheet lead"
        )
        bodyLabel.font = .preferredFont(forTextStyle: .body)
        bodyLabel.adjustsFontForContentSizeCategory = true
        bodyLabel.numberOfLines = 0
        bodyLabel.textColor = .label

        let bulletsLabel = UILabel()
        bulletsLabel.text = NSLocalizedString(
            "• A short recap for people who use the keyboard more than the app\n• One optional reminder, about a day from now — nothing else is scheduled\n• The small What's New chip on the keyboard goes away after this screen",
            comment: "2.0.3 What's New sheet bullets"
        )
        bulletsLabel.font = .preferredFont(forTextStyle: .body)
        bulletsLabel.adjustsFontForContentSizeCategory = true
        bulletsLabel.numberOfLines = 0
        bulletsLabel.textColor = .secondaryLabel

        let allowButton = UIButton(type: .system)
        allowButton.setTitle(
            NSLocalizedString("Allow a reminder", comment: "2.0.3 What's New primary button"),
            for: .normal
        )
        allowButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        allowButton.titleLabel?.adjustsFontForContentSizeCategory = true
        allowButton.backgroundColor = .primary
        allowButton.setTitleColor(.white, for: .normal)
        allowButton.layer.cornerRadius = 12
        allowButton.addTarget(self, action: #selector(allowTapped), for: .touchUpInside)
        allowButton.accessibilityIdentifier = "whatsnew.allow"

        let skipButton = UIButton(type: .system)
        skipButton.setTitle(
            NSLocalizedString("Not now", comment: "2.0.3 What's New skip button"),
            for: .normal
        )
        skipButton.titleLabel?.font = .preferredFont(forTextStyle: .body)
        skipButton.titleLabel?.adjustsFontForContentSizeCategory = true
        skipButton.addTarget(self, action: #selector(skipTapped), for: .touchUpInside)
        skipButton.accessibilityIdentifier = "whatsnew.skip"

        let stack = UIStackView(arrangedSubviews: [titleLabel, bodyLabel, bulletsLabel, allowButton, skipButton])
        stack.axis = .vertical
        stack.spacing = 16
        stack.setCustomSpacing(24, after: bulletsLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 28),
            allowButton.heightAnchor.constraint(equalToConstant: 52)
        ])
    }

    @objc private func allowTapped() {
        UNUserNotificationCenter.current().requestAuthorization(options: WhatsNewNotification.authorizationOptions) { granted, _ in
            DispatchQueue.main.async {
                WhatsNewNotification.scheduleIfGranted(granted)
                self.dismiss(animated: true)
            }
        }
    }

    @objc private func skipTapped() {
        dismiss(animated: true)
    }
}
