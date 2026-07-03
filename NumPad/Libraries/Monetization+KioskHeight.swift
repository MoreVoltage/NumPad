//
//  Monetization+KioskHeight.swift
//  NumPad
//
//  Entitlement for the Pro Kiosk keyboard-height preset (2.0). Unlike the Customizable Keyboard,
//  Kiosk has no standalone à la carte product — it unlocks with Pro (or a grandfathered install)
//  only.
//

import Foundation

extension Monetization {
    /// Whether the Kiosk keyboard-height preset is unlocked for the current user. No standalone
    /// purchase exists for it, so this is exactly the Pro entitlement.
    static var isKioskHeightEntitled: Bool { isProEntitled }
}
