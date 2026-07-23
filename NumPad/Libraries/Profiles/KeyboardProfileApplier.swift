//
//  KeyboardProfileApplier.swift
//  NumPad
//

import Foundation

struct ProfileEntitlements: Equatable {
    let pro: Bool
    let kioskHeight: Bool
    let financePack: Bool
}

enum ProfileFallback: Equatable {
    case heightKioskToTall
    case packLocked(String)
    case customKeyboardLocked
    case qwertyPageLocked
    case themePremiumToWhite(String)
}

struct ApplyResult: Equatable {
    let changedKeys: Set<String>
    let fallbacks: [ProfileFallback]
}

struct KeyboardProfileApplier {
    let defaults: UserDefaults
    var notify: () -> Void = { SettingsSync.post() }

    func apply(_ profile: KeyboardProfile, entitlements: ProfileEntitlements) throws -> ApplyResult {
        let validated = try profile.validated()
        var config = validated.configuration
        var fallbacks: [ProfileFallback] = []
        var changed: Set<String> = []

        // Entitlement fallbacks — profile values stay unchanged; applied values may differ.
        if config.heightRaw == KeyboardHeightPreset.kiosk.rawValue, !entitlements.kioskHeight {
            config.heightRaw = KeyboardHeightPreset.tall.rawValue
            fallbacks.append(.heightKioskToTall)
        }

        if let type = KeyboardType(rawValue: config.keyboardTypeRaw),
           MonetizationGating.isPackLocked(type, entitlements: entitlements) {
            fallbacks.append(.packLocked(config.keyboardTypeRaw))
            config.keyboardTypeRaw = KeyboardType.default.rawValue
        }

        if config.customKeyboardConfig != nil, !entitlements.pro {
            fallbacks.append(.customKeyboardLocked)
            config.customKeyboardConfig = nil
        }

        if config.keyboardPageRaw == "qwerty", !entitlements.pro {
            fallbacks.append(.qwertyPageLocked)
            config.keyboardPageRaw = "numpad"
        }

        if let theme = KeyboardTheme(rawValue: config.themeRaw),
           KeyboardTheme.premiumThemes.contains(theme),
           !entitlements.pro {
            fallbacks.append(.themePremiumToWhite(config.themeRaw))
            config.themeRaw = KeyboardTheme.white.rawValue
        }

        func write(_ key: String, _ value: Any?) {
            let previous = defaults.object(forKey: key)
            if let value = value {
                if let prev = previous as? NSObject, let new = value as? NSObject, prev.isEqual(new) {
                    return
                }
                defaults.set(value, forKey: key)
            } else {
                if previous == nil { return }
                defaults.removeObject(forKey: key)
            }
            changed.insert(key)
        }

        write(Constants.selectedKeyboardType.rawValue, config.keyboardTypeRaw)
        write(Constants.selectedKeyboardTheme.rawValue, config.themeRaw)
        write(Constants.automaticDarkMode.rawValue, config.automaticDarkMode)
        write(Constants.heightPreset.rawValue, config.heightRaw)
        write(Constants.reversedMode.rawValue, config.reversedMode)
        write(Constants.roundedCorners.rawValue, config.roundedCorners)
        write(Constants.grid.rawValue, config.grid)
        write(Constants.handedness.rawValue, config.handednessRaw)
        write(Constants.hapticsEnabled.rawValue, config.hapticsEnabled)
        write(Constants.soundEnabled.rawValue, config.soundEnabled)
        write(Constants.repurposeNextKey.rawValue, config.repurposeNextKey)
        write(Constants.clipboardHistoryEnabled.rawValue, config.clipboardHistoryEnabled)
        write(Constants.inlineCalculatorEnabled.rawValue, config.inlineCalculator)
        write(Constants.liveMathPreviewEnabled.rawValue, config.liveMathPreview)
        write(Constants.cursorControlsEnabled.rawValue, config.cursorControls)
        write(Constants.smartPackDefaultingEnabled.rawValue, config.smartPackDefaulting)
        write(Constants.lastResultTapeEnabled.rawValue, config.resultTapeEnabled)
        write(Constants.keyboardPage.rawValue, config.keyboardPageRaw)
        write(Constants.qwertyPrimaryPack.rawValue, config.qwertyPrimaryPackRaw)
        write(Constants.packDisplayBehavior.rawValue, config.packDisplayBehaviorRaw)
        write(Constants.qwertyPeriodComma.rawValue, config.qwertyPeriodComma)
        write(Constants.qwertyAutocorrectEnabled.rawValue, config.qwertyAutocorrect)
        write(Constants.qwertySuggestionsEnabled.rawValue, config.qwertySuggestions)
        write(Constants.qwertyDoubleSpacePeriodEnabled.rawValue, config.qwertyDoubleSpacePeriod)
        write(Constants.qwertyLayoutMode.rawValue, config.qwertyLayoutModeRaw)
        write(Constants.numpadPlacement.rawValue, config.numpadPlacementRaw)

        var store = CustomKeyboardStore(defaults: defaults)
        store.onChange = {}
        if let custom = config.customKeyboardConfig {
            let previous = store.load()
            if previous != custom {
                store.save(custom)
                changed.insert(Constants.customKeyboardConfig.rawValue)
            }
        }

        // Persist active id without going through profile blob mutation.
        defaults.set(validated.id.uuidString, forKey: Constants.activeKeyboardProfileID.rawValue)
        changed.insert(Constants.activeKeyboardProfileID.rawValue)

        notify()
        return ApplyResult(changedKeys: changed, fallbacks: fallbacks)
    }
}

/// Thin entitlement check for packs without requiring Monetization statics in unit tests.
enum MonetizationGating {
    static func isPackLocked(_ type: KeyboardType, entitlements: ProfileEntitlements) -> Bool {
        switch type {
        case .default, .math, .math2, .tax:
            return false
        case .finance:
            return !(entitlements.pro || entitlements.financePack)
        case .custom:
            return !entitlements.pro
        default:
            // Remaining selectable packs are Pro or à-la-carte; treat as Pro-gated in profiles.
            return !entitlements.pro
        }
    }
}
