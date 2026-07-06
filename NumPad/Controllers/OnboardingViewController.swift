//
//  OnboardingViewController.swift
//  NumPad
//
//  Container for the 3-step interactive first-run onboarding (WOW -> ENABLE -> TRY IT), presented
//  full-screen, once, ahead of the app's normal launch flow (see ViewController.finishLaunch /
//  OnboardingFlow.shouldShow). Skippable at every step; either finishing naturally or skipping calls
//  `completion` after dismissal so the caller can hand off to the existing first-run-upsell funnel
//  (`ViewController.presentFirstRunUpsellIfNeeded`) exactly once, at the moment onboarding ends.
//

import UIKit

final class OnboardingViewController: UIViewController {
    private let completion: () -> Void
    private var currentStep: OnboardingStep = .wow
    private var currentChild: UIViewController?

    private let progressView = OnboardingProgressView(stepCount: OnboardingStep.allCases.count)
    private let skipButton = UIButton(type: .system)

    private lazy var wowViewController: OnboardingWowViewController = {
        let vc = OnboardingWowViewController()
        vc.onContinue = { [weak self] in self?.advance(from: .wow) }
        return vc
    }()
    private lazy var enableViewController: OnboardingEnableViewController = {
        let vc = OnboardingEnableViewController()
        vc.onEnabled = { [weak self] in self?.advance(from: .enable) }
        return vc
    }()
    private lazy var tryItViewController: OnboardingTryItViewController = {
        let vc = OnboardingTryItViewController()
        vc.onDone = { [weak self] in self?.complete() }
        return vc
    }()

    init(completion: @escaping () -> Void) {
        self.completion = completion
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        skipButton.setTitle(NSLocalizedString("Skip", comment: "Onboarding: dismiss the first-run walkthrough"), for: .normal)
        skipButton.titleLabel?.font = .preferredFont(forTextStyle: .subheadline)
        skipButton.accessibilityIdentifier = "onboarding.skip"
        skipButton.addTarget(self, action: #selector(skipTapped), for: .touchUpInside)
        skipButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(skipButton)

        progressView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(progressView)

        NSLayoutConstraint.activate([
            skipButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            skipButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),

            progressView.centerYAnchor.constraint(equalTo: skipButton.centerYAnchor),
            progressView.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])

        showStep(.wow, animated: false)
    }

    private func child(for step: OnboardingStep) -> UIViewController {
        switch step {
        case .wow: return wowViewController
        case .enable: return enableViewController
        case .tryIt: return tryItViewController
        }
    }

    private func advance(from step: OnboardingStep) {
        guard currentStep == step, let next = step.next else { return }
        if step == .wow { wowViewController.stop() }
        showStep(next, animated: true)
    }

    private func showStep(_ step: OnboardingStep, animated: Bool) {
        currentStep = step
        progressView.currentIndex = step.rawValue
        transition(to: child(for: step), animated: animated)
        Analytics.logEvent(name: "onboarding_step_viewed", attributes: ["step": step.analyticsValue])
    }

    private func transition(to child: UIViewController, animated: Bool) {
        guard child !== currentChild else { return }
        let previous = currentChild

        addChild(child)
        child.view.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(child.view, at: 0)
        NSLayoutConstraint.activate([
            child.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            child.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            child.view.topAnchor.constraint(equalTo: view.topAnchor),
            child.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        child.didMove(toParent: self)
        currentChild = child

        let removePrevious: () -> Void = {
            previous?.willMove(toParent: nil)
            previous?.view.removeFromSuperview()
            previous?.removeFromParent()
        }

        guard animated, let previous = previous, !UIAccessibility.isReduceMotionEnabled else {
            removePrevious()
            return
        }

        child.view.alpha = 0
        child.view.transform = CGAffineTransform(translationX: 24, y: 0)
        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.9, initialSpringVelocity: 0, options: [.curveEaseInOut], animations: {
            child.view.alpha = 1
            child.view.transform = .identity
            previous.view.alpha = 0
        }, completion: { _ in
            removePrevious()
        })
    }

    @objc private func skipTapped() {
        Analytics.logEvent(name: "onboarding_skipped", attributes: ["step": currentStep.analyticsValue])
        finish()
    }

    private func complete() {
        Analytics.logEvent(name: "onboarding_completed")
        finish()
    }

    private func finish() {
        dismiss(animated: true) { [weak self] in
            self?.completion()
        }
    }
}
