//
//  KioskModeAccess.swift
//  NumPad
//

import Foundation

/// One entitlement rule for every route that can persist or activate a Kiosk setup.
enum KioskModeAccess {
    static func allows(kind: KeyboardProfile.Kind, proEntitled: Bool) -> Bool {
        kind != .kiosk || proEntitled
    }

    static func allows(_ profile: KeyboardProfile, proEntitled: Bool) -> Bool {
        allows(kind: profile.kind, proEntitled: proEntitled)
    }
}
