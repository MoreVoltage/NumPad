//
//  Monetization+FullKeyboard.swift
//  NumPad
//
//  Entitlement for NumPad Type, the full-QWERTY keyboard extension (docs/plans/full-keyboard/
//  §5): gated entirely behind existing Pro — no new SKU, no new price point — matching the
//  Custom Keyboard's "platform capability that deepens Pro" tier.
//

import Foundation

extension Monetization {
    /// Pure entitlement rule, extracted for testing: the paywall being off unlocks everything
    /// (matching every other gate), otherwise Pro/grandfathered is required.
    static func fullKeyboardEntitled(paywallEnabled: Bool, proEntitled: Bool) -> Bool {
        !paywallEnabled || proEntitled
    }

    /// Whether NumPad Type is unlocked for the current user.
    static var isFullKeyboardEntitled: Bool {
        fullKeyboardEntitled(paywallEnabled: paywallEnabled, proEntitled: isProEntitled)
    }
}
