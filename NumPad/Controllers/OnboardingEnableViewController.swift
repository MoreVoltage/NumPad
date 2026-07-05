//
//  OnboardingEnableViewController.swift
//  NumPad
//
//  Step 2 of onboarding: walks the user to Settings > General > Keyboard > Keyboards to add NumPad
//  (reusing the exact copy and deep link `InstructionsViewController` uses, restyled full-screen),
//  then detects enablement live when the app returns to the foreground (`Keyboard.isKeyboardEnabled`
//  — the same signal `KeyboardEnablementTracker` already polls) and celebrates before auto-advancing.
//

import UIKit

final class OnboardingEnableViewController: UIViewController {
    var onEnabled: (() -> Void)?

    private let headlineLabel = UILabel()
    private let bodyLabel = UILabel()
    private let stepsStack = UIStackView()
    private let openSettingsButton = UIButton(type: .system)
    private let footerLabel = UILabel()
    private let confettiView = OnboardingConfettiView()

    private var didAdvance = false
    private var foregroundObserver: NSObjectProtocol?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        buildLayout()

        // Live-detect enablement on every foreground (covers the realistic flow: tap "Go to
        // Settings", enable the keyboard there, come back). Also checked once immediately below for
        // the edge case where the keyboard is somehow already enabled the moment this step loads.
        foregroundObserver = NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            self?.checkEnablement()
        }
        checkEnablement()
    }

    deinit {
        if let observer = foregroundObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func buildLayout() {
        let iconView = UIImageView(image: UIImage(named: "keyboard"))
        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = .primary
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.heightAnchor.constraint(equalToConstant: 44).isActive = true

        headlineLabel.text = NSLocalizedString("One quick setup step", comment: "Onboarding ENABLE step headline")
        headlineLabel.font = .preferredFont(for: .title1, weight: .bold)
        headlineLabel.textAlignment = .center
        headlineLabel.numberOfLines = 0

        bodyLabel.text = .instructionsHeader
        bodyLabel.font = .preferredFont(forTextStyle: .body)
        bodyLabel.textColor = .secondaryLabel
        bodyLabel.textAlignment = .center
        bodyLabel.numberOfLines = 0

        stepsStack.axis = .vertical
        stepsStack.spacing = 14
        stepsStack.alignment = .fill
        for (imageName, text) in [("tap", String.instructionsItem1), ("tap", String.instructionsItem2), ("switch", String.instructionsItem3)] {
            stepsStack.addArrangedSubview(makeStepRow(imageName: imageName, text: text))
        }

        openSettingsButton.setTitle(.goToSettings, for: .normal)
        openSettingsButton.titleLabel?.font = .preferredFont(for: .headline, weight: .bold)
        openSettingsButton.backgroundColor = .primary
        openSettingsButton.titleColor = .white
        openSettingsButton.layer.cornerRadius = 14
        openSettingsButton.accessibilityIdentifier = "onboarding.enable.openSettings"
        openSettingsButton.addTarget(self, action: #selector(openSettingsTapped), for: .touchUpInside)

        footerLabel.text = .instructionsFooter
        footerLabel.font = .preferredFont(forTextStyle: .footnote)
        footerLabel.textColor = .tertiaryLabel
        footerLabel.textAlignment = .center
        footerLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [iconView, headlineLabel, bodyLabel, stepsStack, openSettingsButton, footerLabel])
        stack.axis = .vertical
        stack.spacing = 20
        stack.setCustomSpacing(28, after: bodyLabel)
        stack.setCustomSpacing(28, after: stepsStack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        confettiView.alpha = 0
        confettiView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(confettiView)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -32),
            stack.topAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.topAnchor, constant: 72),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 8),

            openSettingsButton.heightAnchor.constraint(equalToConstant: 52),

            confettiView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            confettiView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            confettiView.topAnchor.constraint(equalTo: view.topAnchor),
            confettiView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func makeStepRow(imageName: String, text: String) -> UIView {
        let imageView = UIImageView(image: UIImage(named: imageName))
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .primary
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.widthAnchor.constraint(equalToConstant: 28).isActive = true
        imageView.heightAnchor.constraint(equalToConstant: 28).isActive = true

        let label = UILabel()
        label.text = text
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.numberOfLines = 0

        let row = UIStackView(arrangedSubviews: [imageView, label])
        row.axis = .horizontal
        row.spacing = 12
        row.alignment = .center
        return row
    }

    private func checkEnablement() {
        guard OnboardingEnableStep.shouldAutoAdvance(keyboardEnabled: Keyboard.isKeyboardEnabled, alreadyAdvanced: didAdvance) else { return }
        celebrateAndAdvance()
    }

    private func celebrateAndAdvance() {
        didAdvance = true

        headlineLabel.text = NSLocalizedString("You're all set!", comment: "Onboarding ENABLE step success headline shown once the keyboard is detected as enabled")
        bodyLabel.text = NSLocalizedString("NumPad is ready to use.", comment: "Onboarding ENABLE step success body shown once the keyboard is detected as enabled")
        stepsStack.isHidden = true
        openSettingsButton.isHidden = true
        footerLabel.isHidden = true

        confettiView.alpha = 1
        confettiView.play { [weak self] in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self?.onEnabled?()
            }
        }
    }

    @objc private func openSettingsTapped() {
        URL.keyboard.map { UIApplication.shared.open($0) }
        Analytics.logEvent(name: "settings")
    }
}
