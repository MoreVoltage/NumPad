//
//  OnboardingTryItViewController.swift
//  NumPad
//
//  Step 3 of onboarding: an in-app text field so the user's first real keystrokes with NumPad
//  happen where we can coach them (a suggested expression, long-press hints) rather than in some
//  other app. Finishing here hands off to the existing new-buyer paywall trigger — see
//  `OnboardingViewController` / `ViewController.presentFirstRunUpsellIfNeeded`.
//

import UIKit

final class OnboardingTryItViewController: UIViewController {
    var onDone: (() -> Void)?

    private let textField = UITextField()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let headlineLabel = UILabel()
        headlineLabel.text = NSLocalizedString("Your turn", comment: "Onboarding TRY IT step headline")
        headlineLabel.font = .preferredFont(for: .title1, weight: .bold)
        headlineLabel.textAlignment = .center
        headlineLabel.numberOfLines = 0

        let subtitleLabel = UILabel()
        subtitleLabel.text = NSLocalizedString("Tap below and try typing 25*4=", comment: "Onboarding TRY IT step subtitle suggesting an example expression to try")
        subtitleLabel.font = .preferredFont(forTextStyle: .body)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0

        textField.borderStyle = .roundedRect
        textField.font = .preferredFont(forTextStyle: .title2)
        textField.textAlignment = .center
        textField.placeholder = NSLocalizedString("25*4=", comment: "Onboarding TRY IT step text field placeholder example expression")
        textField.accessibilityIdentifier = "onboarding.tryIt.textField"

        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        let flex = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let doneItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(finishTapped))
        toolbar.items = [flex, doneItem]
        textField.inputAccessoryView = toolbar

        let hintLabel = UILabel()
        hintLabel.text = NSLocalizedString("Tip: long-press 0 for clipboard history, . for snippets, or % for tax & tip.", comment: "Onboarding TRY IT step hint about the keyboard's long-press overlays")
        hintLabel.font = .preferredFont(forTextStyle: .footnote)
        hintLabel.textColor = .secondaryLabel
        hintLabel.textAlignment = .center
        hintLabel.numberOfLines = 0

        // Honest pricing plant right before the new-buyer paywall handoff: NumPad is a paid app, so
        // this never implies "free" — it only sets the no-subscription expectation for the upsell.
        let noSubLabel = UILabel()
        noSubLabel.text = NSLocalizedString("No subscriptions, ever. Pro is a one-time unlock.", comment: "Onboarding TRY IT step reassurance shown before the paywall — NumPad has no subscriptions")
        noSubLabel.font = .preferredFont(forTextStyle: .footnote)
        noSubLabel.textColor = .tertiaryLabel
        noSubLabel.textAlignment = .center
        noSubLabel.numberOfLines = 0

        let finishButton = UIButton(type: .system)
        finishButton.setTitle(NSLocalizedString("Done", comment: "Onboarding TRY IT step button to finish onboarding"), for: .normal)
        finishButton.titleLabel?.font = .preferredFont(for: .headline, weight: .bold)
        finishButton.backgroundColor = .primary
        finishButton.titleColor = .white
        finishButton.layer.cornerRadius = 14
        finishButton.accessibilityIdentifier = "onboarding.tryIt.done"
        finishButton.addTarget(self, action: #selector(finishTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [headlineLabel, subtitleLabel, textField, hintLabel, noSubLabel, finishButton])
        stack.axis = .vertical
        stack.spacing = 20
        stack.setCustomSpacing(28, after: subtitleLabel)
        stack.setCustomSpacing(8, after: hintLabel)
        stack.setCustomSpacing(28, after: noSubLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -32),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 96),

            textField.heightAnchor.constraint(equalToConstant: 52),
            finishButton.heightAnchor.constraint(equalToConstant: 52)
        ])

        // Raise the keyboard once this step has settled on screen. Scheduled directly (rather than
        // from viewWillAppear/viewDidAppear) for the same containment reason documented in
        // OnboardingWowViewController — this step is swapped in after the onboarding container is
        // already visible, so automatic appearance-method forwarding doesn't reach it.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.textField.becomeFirstResponder()
        }
    }

    @objc private func finishTapped() {
        textField.resignFirstResponder()
        onDone?()
    }
}
