//
//  OnboardingWowViewController.swift
//  NumPad
//
//  Step 1 of onboarding: a full-screen animated demo of the keyboard's headline feature (live math)
//  with the pack catalog cycling underneath, plus a single five-word value headline. Deliberately no
//  feature list — the demo is the pitch.
//

import UIKit

final class OnboardingWowViewController: UIViewController {
    var onContinue: (() -> Void)?

    private let mockView = OnboardingKeyboardMockView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let headlineLabel = UILabel()
        headlineLabel.text = NSLocalizedString("Math, right where you type.", comment: "Onboarding WOW step headline — five words describing the core value of the keyboard")
        headlineLabel.font = .preferredFont(for: .largeTitle, weight: .bold)
        headlineLabel.textAlignment = .center
        headlineLabel.numberOfLines = 0
        headlineLabel.translatesAutoresizingMaskIntoConstraints = false

        mockView.translatesAutoresizingMaskIntoConstraints = false

        let continueButton = UIButton(type: .system)
        continueButton.setTitle(NSLocalizedString("Get Started", comment: "Onboarding WOW step button to continue to the next step"), for: .normal)
        continueButton.titleLabel?.font = .preferredFont(for: .headline, weight: .bold)
        continueButton.backgroundColor = .primary
        continueButton.titleColor = .white
        continueButton.layer.cornerRadius = 14
        continueButton.translatesAutoresizingMaskIntoConstraints = false
        continueButton.accessibilityIdentifier = "onboarding.wow.continue"
        continueButton.addTarget(self, action: #selector(continueTapped), for: .touchUpInside)

        view.addSubview(headlineLabel)
        view.addSubview(mockView)
        view.addSubview(continueButton)

        NSLayoutConstraint.activate([
            headlineLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 88),
            headlineLabel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 32),
            headlineLabel.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -32),

            mockView.topAnchor.constraint(greaterThanOrEqualTo: headlineLabel.bottomAnchor, constant: 40),
            mockView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            mockView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
            mockView.bottomAnchor.constraint(lessThanOrEqualTo: continueButton.topAnchor, constant: -32),
            mockView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 10),

            continueButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 32),
            continueButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -32),
            continueButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -32),
            continueButton.heightAnchor.constraint(equalToConstant: 52)
        ])

        // Started here (rather than viewWillAppear/viewDidAppear) because this step is added to the
        // onboarding container as a child view controller — later steps are swapped in after the
        // container is already on screen, and UIKit's automatic appearance-method forwarding only
        // covers children present at the container's OWN appearance transition. Starting from
        // viewDidLoad (called exactly once, right when this step first becomes the visible child)
        // sidesteps that entirely and keeps all three onboarding steps consistent.
        mockView.startAnimating()
    }

    /// Called by the container right before swapping away from this step, so the demo loop's
    /// recurring `asyncAfter` chain doesn't keep quietly ticking (and repainting) once off-screen.
    func stop() {
        mockView.stopAnimating()
    }

    @objc private func continueTapped() {
        onContinue?()
    }
}
