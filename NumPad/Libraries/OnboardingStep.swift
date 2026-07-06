//
//  OnboardingStep.swift
//  NumPad
//
//  The 3-step sequence for the interactive first-run onboarding, plus the pure auto-advance
//  decision for the ENABLE step (fires once live keyboard enablement is detected). Kept UIKit-free
//  for unit testing, mirroring OnboardingFlow.
//

import Foundation

enum OnboardingStep: Int, CaseIterable, Equatable {
    case wow, enable, tryIt

    /// The step after this one, or `nil` when this is the last step — TRY IT finishes the flow
    /// through an explicit "Done" action rather than an automatic `next`.
    var next: OnboardingStep? {
        switch self {
        case .wow: return .enable
        case .enable: return .tryIt
        case .tryIt: return nil
        }
    }

    /// Stable analytics value for `onboarding_step_viewed` / `onboarding_skipped`.
    var analyticsValue: String {
        switch self {
        case .wow: return "wow"
        case .enable: return "enable"
        case .tryIt: return "try_it"
        }
    }
}

/// Pure decision for the ENABLE step: whether to celebrate and auto-advance right now.
enum OnboardingEnableStep {
    /// `alreadyAdvanced` guards a spurious repeat foreground (e.g. the user backgrounds the app
    /// again after already being auto-advanced) from re-triggering the celebration.
    static func shouldAutoAdvance(keyboardEnabled: Bool, alreadyAdvanced: Bool) -> Bool {
        keyboardEnabled && !alreadyAdvanced
    }
}
