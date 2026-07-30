//
//  StudioSavedSetupPresentation.swift
//  NumPad
//

import UIKit

/// Presentation-only language for the saved-setup workflow. It deliberately leaves the factory
/// identities untouched and uses `probe` for every projected state.
enum StudioSavedSetupPresentation {
    struct Item: Equatable {
        let profile: KeyboardProfile
        let name: String
        let detail: String
    }

    struct Change: Equatable {
        let label: String
        let value: String
    }

    struct ProjectedSummary {
        let preview: StudioKeyboardPreviewModel
        let changes: [Change]
        let fallbacks: [ProfileFallback]
    }

    static func builtIns(qwertyAvailable: Bool) -> [Item] {
        KeyboardProfileFactory.builtIns().compactMap { profile in
            guard profile.kind != .writing || qwertyAvailable else { return nil }
            return item(for: profile)
        }
    }

    static func item(for profile: KeyboardProfile) -> Item {
        let copy: (String, String)
        switch profile.kind {
        case .standard:
            copy = ("Everyday numbers", "A clean NumPad for forms, codes, and ordinary number entry")
        case .calculator:
            copy = ("Calculator", "Math operators, calculator number order, regular-height keys")
        case .finance:
            copy = ("Prices & payments", "Currency and finance keys")
        case .inventory:
            copy = ("Measurements", "Units and conversion keys")
        case .writing:
            copy = ("Writing", "Letters page and suggestions")
        case .accessibility:
            copy = ("Easy to see", "Taller, high-contrast keys with stronger sound and vibration")
        case .kiosk:
            copy = ("Kiosk", "Shared-use setup that clears session state after inactivity")
        case .custom:
            copy = (profile.name, "Your saved keyboard choices")
        }
        return Item(profile: profile, name: NSLocalizedString(copy.0, comment: "Saved setup name"), detail: NSLocalizedString(copy.1, comment: "Saved setup description"))
    }

    static func projectedSummary(
        for profile: KeyboardProfile,
        idiom: UIUserInterfaceIdiom,
        applier: KeyboardProfileApplier = KeyboardProfileApplier(defaults: .group),
        entitlements: ProfileEntitlements = .live()
    ) throws -> ProjectedSummary {
        let result = try applier.probe(profile, entitlements: entitlements)
        let current = KeyboardProfileFactory.snapshotCurrent(defaults: applier.defaults).configuration
        return ProjectedSummary(
            preview: StudioKeyboardPreviewModel.projected(
                from: profile.configuration,
                idiom: idiom,
                applier: applier,
                entitlements: entitlements
            ),
            changes: changes(from: current, to: result.appliedConfiguration),
            fallbacks: result.fallbacks
        )
    }

    private static func changes(
        from current: KeyboardProfile.Configuration,
        to proposed: KeyboardProfile.Configuration
    ) -> [Change] {
        var result: [Change] = []
        if current.keyboardTypeRaw != proposed.keyboardTypeRaw {
            result.append(Change(label: "Key set", value: KeyboardType(rawValue: proposed.keyboardTypeRaw)?.name ?? proposed.keyboardTypeRaw))
        }
        if current.heightRaw != proposed.heightRaw {
            result.append(Change(label: "Key height", value: KeyboardHeightPreset(rawValue: proposed.heightRaw)?.name ?? proposed.heightRaw.capitalized))
        }
        if current.themeRaw != proposed.themeRaw {
            result.append(Change(label: "Color", value: KeyboardTheme(rawValue: proposed.themeRaw)?.name ?? proposed.themeRaw))
        }
        if current.reversedMode != proposed.reversedMode {
            result.append(Change(label: "Number order", value: proposed.reversedMode ? "Calculator order" : "Standard order"))
        }
        if current.keyboardPageRaw != proposed.keyboardPageRaw {
            result.append(Change(label: "Keyboard page", value: proposed.keyboardPageRaw == "qwerty" ? "Letters" : "Numbers"))
        }
        if current.hapticsEnabled != proposed.hapticsEnabled || current.soundEnabled != proposed.soundEnabled {
            result.append(Change(label: "Feedback", value: proposed.hapticsEnabled || proposed.soundEnabled ? "Sound and vibration on" : "Sound and vibration off"))
        }
        if current.roundedCorners != proposed.roundedCorners || current.grid != proposed.grid {
            result.append(Change(label: "Key appearance", value: proposed.roundedCorners ? "Rounded keys" : "Square keys"))
        }
        if result.isEmpty { result.append(Change(label: "Keyboard", value: "Already matches this setup")) }
        return result
    }
}

enum StudioAdvancedPresentation {
    static func showsManagedSettings(hasManagedOwnership: Bool) -> Bool { hasManagedOwnership }
}
