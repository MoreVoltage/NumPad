//
//  Monetization+CustomKeyboard.swift
//  NumPad
//
//  Entitlement for the fully-customizable keyboard (2.0 Phase 1). Additive: the standalone
//  "numpad.feature.customkeyboard" non-consumable unlocks it, and Pro / grandfathered cover it too.
//

import Foundation

extension Monetization {
    /// True when the standalone Customizable Keyboard non-consumable is owned. Stored in the shared
    /// app group so the keyboard extension reads the same value the app writes. (Computed rather than
    /// `@UserDefault` because a property wrapper can't add a stored property in an extension.)
    static var isCustomKeyboardPurchased: Bool {
        get { UserDefaults.group.bool(forKey: Constants.customKeyboardPurchased.rawValue) }
        set { UserDefaults.group.set(newValue, forKey: Constants.customKeyboardPurchased.rawValue) }
    }

    /// Pure entitlement rule, extracted for testing.
    static func customKeyboardEntitled(proEntitled: Bool, standalonePurchased: Bool) -> Bool {
        proEntitled || standalonePurchased
    }

    /// Whether the fully-customizable keyboard is unlocked for the current user: Pro (or a
    /// grandfathered install) covers it, or the standalone Customizable Keyboard purchase.
    static var isCustomKeyboardEntitled: Bool {
        customKeyboardEntitled(proEntitled: isProEntitled, standalonePurchased: isCustomKeyboardPurchased)
    }
}
