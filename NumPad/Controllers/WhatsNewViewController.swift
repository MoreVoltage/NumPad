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
        titleLabel.text = NSLocalizedString("Stay up to date with NumPad", comment: "2.0.3 What's New sheet heading")
        titleLabel.font = .preferredFont(forTextStyle: .title2)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.numberOfLines = 0

        let bodyLabel = UILabel()
        bodyLabel.text = NSLocalizedString(
            "Get occasional notifications about new features and app updates, even when you mostly use the keyboard.",
            comment: "2.0.3 What's New sheet lead"
        )
        bodyLabel.font = .preferredFont(forTextStyle: .body)
        bodyLabel.adjustsFontForContentSizeCategory = true
        bodyLabel.numberOfLines = 0
        bodyLabel.textColor = .label

        let bulletsLabel = UILabel()
        bulletsLabel.text = NSLocalizedString(
            "• Choose whether to receive update notifications\n• Turn them off any time in Update Notifications\n• The keyboard works normally with notifications off",
            comment: "2.0.3 What's New sheet bullets"
        )
        bulletsLabel.font = .preferredFont(forTextStyle: .body)
        bulletsLabel.adjustsFontForContentSizeCategory = true
        bulletsLabel.numberOfLines = 0
        bulletsLabel.textColor = .secondaryLabel

        let allowButton = UIButton(type: .system)
        allowButton.setTitle(
            NSLocalizedString("Turn on updates", comment: "2.0.3 What's New primary button"),
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
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.alwaysBounceVertical = true
        view.addSubview(scroll)
        scroll.addSubview(stack)

        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -24),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -48),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 28),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -24),
            allowButton.heightAnchor.constraint(equalToConstant: 52)
        ])
    }

    @objc private func allowTapped() {
        view.isUserInteractionEnabled = false
        UpdateNotifications.shared.requestEnable { [weak self] result in
            guard let self else { return }
            self.view.isUserInteractionEnabled = true
            switch result {
            case .enabled:
                self.dismiss(animated: true)
            case .denied:
                UpdateNotificationsViewController.showPermissionHelp(from: self)
            case .failed:
                let alert = UIAlertController(title: NSLocalizedString("Couldn’t enable notifications", comment: "Notification permission error"),
                    message: NSLocalizedString("Please try again.", comment: "Notification permission retry"), preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Dismiss"), style: .default))
                self.present(alert, animated: true)
            case .cancelled:
                break
            }
        }
    }

    @objc private func skipTapped() {
        dismiss(animated: true)
    }
}
