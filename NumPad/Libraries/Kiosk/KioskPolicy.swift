//
//  KioskPolicy.swift
//  NumPad + Keyboard
//
//  Shared kiosk session policy (Codable). Lives outside KeyboardProfile so the
//  Keyboard extension can enforce inactivity reset without the full profile stack.
//

import Foundation

struct KioskPolicy: Codable, Equatable {
    var inactivityTimeout: TimeInterval
    var resetPageAndPack: Bool
    var dismissOverlays: Bool
    var clearResultTape: Bool
    var clearClipboardHistory: Bool
    var requireAdministratorAuthentication: Bool

    enum ValidationError: Error, Equatable {
        case invalidTimeout(TimeInterval)
    }

    func validated() throws {
        guard inactivityTimeout >= 30, inactivityTimeout <= 3600 else {
            throw ValidationError.invalidTimeout(inactivityTimeout)
        }
    }
}

enum KioskSessionPolicy {
    enum ResetAction: Hashable {
        case dismissOverlays
        case resetPageAndPack
        case clearResultTape
        case clearClipboardHistory
    }

    static func actions(policy: KioskPolicy,
                        lastInteraction: Date,
                        now: Date) -> Set<ResetAction> {
        guard now.timeIntervalSince(lastInteraction) >= policy.inactivityTimeout else {
            return []
        }
        var actions: Set<ResetAction> = []
        if policy.dismissOverlays { actions.insert(.dismissOverlays) }
        if policy.resetPageAndPack { actions.insert(.resetPageAndPack) }
        if policy.clearResultTape { actions.insert(.clearResultTape) }
        if policy.clearClipboardHistory { actions.insert(.clearClipboardHistory) }
        return actions
    }

    /// Load the active profile's kiosk policy from the app group, if any.
    static func activePolicy(defaults: UserDefaults = .group) -> KioskPolicy? {
        guard let idRaw = defaults.string(forKey: Constants.activeKeyboardProfileID.rawValue),
              let id = UUID(uuidString: idRaw),
              let data = defaults.data(forKey: Constants.keyboardProfiles.rawValue),
              let profiles = try? JSONDecoder().decode([KioskProfilePolicyEnvelope].self, from: data),
              let match = profiles.first(where: { $0.id == id }) else {
            return nil
        }
        return match.kioskPolicy
    }
}

/// Minimal decode envelope so the Keyboard target can read `kioskPolicy` without compiling the
/// full `KeyboardProfile` graph (custom keyboard config, themes, etc.).
private struct KioskProfilePolicyEnvelope: Codable {
    let id: UUID
    let kioskPolicy: KioskPolicy?
}
