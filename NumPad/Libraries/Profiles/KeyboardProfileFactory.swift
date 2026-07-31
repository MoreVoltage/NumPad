//
//  KeyboardProfileFactory.swift
//  NumPad
//

import Foundation

enum KeyboardProfileFactory {
    /// Fixed UUIDs so built-ins are stable across launches and never duplicate.
    enum BuiltInID {
        static let standard = UUID(uuidString: "00000000-0000-4000-8000-000000000001")!
        static let calculator = UUID(uuidString: "00000000-0000-4000-8000-000000000002")!
        static let finance = UUID(uuidString: "00000000-0000-4000-8000-000000000003")!
        static let inventory = UUID(uuidString: "00000000-0000-4000-8000-000000000004")!
        static let writing = UUID(uuidString: "00000000-0000-4000-8000-000000000005")!
        static let accessibility = UUID(uuidString: "00000000-0000-4000-8000-000000000006")!
        static let kiosk = UUID(uuidString: "00000000-0000-4000-8000-000000000007")!
    }

    static func builtIns() -> [KeyboardProfile] {
        [standard(), calculator(), finance(), inventory(), writing(), accessibility(), kiosk()]
    }

    static func standard() -> KeyboardProfile {
        make(id: BuiltInID.standard, name: NSLocalizedString("Standard", comment: "Built-in keyboard profile name"), kind: .standard, base: .productionDefaults)
    }

    static func calculator() -> KeyboardProfile {
        var config = KeyboardProfile.Configuration.productionDefaults
        config.keyboardTypeRaw = KeyboardType.math.rawValue
        config.reversedMode = true
        config.heightRaw = KeyboardHeightPreset.regular.rawValue
        return make(id: BuiltInID.calculator, name: NSLocalizedString("Calculator", comment: "Built-in keyboard profile name"), kind: .calculator, base: config)
    }

    static func finance() -> KeyboardProfile {
        var config = KeyboardProfile.Configuration.productionDefaults
        config.keyboardTypeRaw = KeyboardType.finance.rawValue
        config.themeRaw = KeyboardTheme.teal.rawValue
        return make(id: BuiltInID.finance, name: NSLocalizedString("Finance", comment: "Built-in keyboard profile name"), kind: .finance, base: config)
    }

    static func inventory() -> KeyboardProfile {
        var config = KeyboardProfile.Configuration.productionDefaults
        config.keyboardTypeRaw = KeyboardType.units.rawValue
        config.grid = true
        config.roundedCorners = true
        return make(id: BuiltInID.inventory, name: NSLocalizedString("Inventory", comment: "Built-in keyboard profile name"), kind: .inventory, base: config)
    }

    static func writing() -> KeyboardProfile {
        var config = KeyboardProfile.Configuration.productionDefaults
        config.keyboardPageRaw = "qwerty"
        config.qwertySuggestions = true
        // Keep autocorrect off until confidence gates pass — suggestions remain available.
        config.qwertyAutocorrect = false
        config.qwertyPeriodComma = true
        return make(id: BuiltInID.writing, name: NSLocalizedString("Writing", comment: "Built-in keyboard profile name"), kind: .writing, base: config)
    }

    static func accessibility() -> KeyboardProfile {
        var config = KeyboardProfile.Configuration.productionDefaults
        config.heightRaw = KeyboardHeightPreset.tall.rawValue
        config.roundedCorners = true
        config.grid = true
        config.hapticsEnabled = true
        config.soundEnabled = true
        config.themeRaw = KeyboardTheme.black.rawValue
        return make(id: BuiltInID.accessibility, name: NSLocalizedString("Accessibility", comment: "Built-in keyboard profile name"), kind: .accessibility, base: config)
    }

    static func kiosk() -> KeyboardProfile {
        var config = KeyboardProfile.Configuration.productionDefaults
        config.heightRaw = KeyboardHeightPreset.kiosk.rawValue
        config.themeRaw = KeyboardTheme.black.rawValue
        config.numpadPlacementRaw = NumpadPlacement.center.rawValue
        config.roundedCorners = true
        config.grid = true
        config.keyboardPageRaw = "numpad"
        config.clipboardHistoryEnabled = false
        config.resultTapeEnabled = true
        let policy = KioskPolicy(
            inactivityTimeout: 120,
            resetPageAndPack: true,
            dismissOverlays: true,
            clearResultTape: true,
            clearClipboardHistory: true,
            requireAdministratorAuthentication: true
        )
        return KeyboardProfile(
            id: BuiltInID.kiosk,
            name: NSLocalizedString("Kiosk", comment: "Built-in keyboard profile name"),
            kind: .kiosk,
            configuration: config,
            kioskPolicy: policy,
            schemaVersion: KeyboardProfile.currentSchemaVersion
        )
    }

    /// Snapshot the live settings into a custom profile without reading personal content stores.
    static func snapshotCurrent(name: String = "My Current Setup",
                                defaults: UserDefaults = .group) -> KeyboardProfile {
        let custom = CustomKeyboardStore(defaults: defaults).load()
        let production = KeyboardProfile.Configuration.productionDefaults
        let config = KeyboardProfile.Configuration(
            keyboardTypeRaw: defaults.string(forKey: Constants.selectedKeyboardType.rawValue) ?? production.keyboardTypeRaw,
            themeRaw: defaults.string(forKey: Constants.selectedKeyboardTheme.rawValue) ?? production.themeRaw,
            automaticDarkMode: (defaults.object(forKey: Constants.automaticDarkMode.rawValue) as? Bool) ?? production.automaticDarkMode,
            heightRaw: defaults.string(forKey: Constants.heightPreset.rawValue) ?? production.heightRaw,
            reversedMode: (defaults.object(forKey: Constants.reversedMode.rawValue) as? Bool) ?? production.reversedMode,
            roundedCorners: (defaults.object(forKey: Constants.roundedCorners.rawValue) as? Bool) ?? production.roundedCorners,
            grid: (defaults.object(forKey: Constants.grid.rawValue) as? Bool) ?? production.grid,
            customKeyboardConfig: custom,
            handednessRaw: defaults.string(forKey: Constants.handedness.rawValue) ?? production.handednessRaw,
            hapticsEnabled: (defaults.object(forKey: Constants.hapticsEnabled.rawValue) as? Bool) ?? production.hapticsEnabled,
            soundEnabled: (defaults.object(forKey: Constants.soundEnabled.rawValue) as? Bool) ?? production.soundEnabled,
            repurposeNextKey: (defaults.object(forKey: Constants.repurposeNextKey.rawValue) as? Bool) ?? production.repurposeNextKey,
            clipboardHistoryEnabled: (defaults.object(forKey: Constants.clipboardHistoryEnabled.rawValue) as? Bool) ?? production.clipboardHistoryEnabled,
            inlineCalculator: (defaults.object(forKey: Constants.inlineCalculatorEnabled.rawValue) as? Bool) ?? production.inlineCalculator,
            liveMathPreview: (defaults.object(forKey: Constants.liveMathPreviewEnabled.rawValue) as? Bool) ?? production.liveMathPreview,
            cursorControls: (defaults.object(forKey: Constants.cursorControlsEnabled.rawValue) as? Bool) ?? production.cursorControls,
            smartPackDefaulting: (defaults.object(forKey: Constants.smartPackDefaultingEnabled.rawValue) as? Bool) ?? production.smartPackDefaulting,
            resultTapeEnabled: (defaults.object(forKey: Constants.lastResultTapeEnabled.rawValue) as? Bool) ?? production.resultTapeEnabled,
            keyboardPageRaw: defaults.string(forKey: Constants.keyboardPage.rawValue) ?? production.keyboardPageRaw,
            qwertyPrimaryPackRaw: defaults.string(forKey: Constants.qwertyPrimaryPack.rawValue),
            packDisplayBehaviorRaw: defaults.string(forKey: Constants.packDisplayBehavior.rawValue) ?? production.packDisplayBehaviorRaw,
            qwertyPeriodComma: (defaults.object(forKey: Constants.qwertyPeriodComma.rawValue) as? Bool) ?? production.qwertyPeriodComma,
            qwertyAutocorrect: (defaults.object(forKey: Constants.qwertyAutocorrectEnabled.rawValue) as? Bool) ?? production.qwertyAutocorrect,
            qwertySuggestions: (defaults.object(forKey: Constants.qwertySuggestionsEnabled.rawValue) as? Bool) ?? production.qwertySuggestions,
            qwertyDoubleSpacePeriod: (defaults.object(forKey: Constants.qwertyDoubleSpacePeriodEnabled.rawValue) as? Bool) ?? production.qwertyDoubleSpacePeriod,
            qwertyLayoutModeRaw: defaults.string(forKey: Constants.qwertyLayoutMode.rawValue) ?? production.qwertyLayoutModeRaw,
            numpadPlacementRaw: defaults.string(forKey: Constants.numpadPlacement.rawValue) ?? production.numpadPlacementRaw,
            numpadWidthSizeRaw: UserPrefs.readNumpadWidthSize(from: defaults).rawValue,
            iPadQwertyLayoutRaw: UserPrefs.readIPadQwertyLayout(from: defaults).rawValue,
            fullKeyboardNumpadSideRaw: UserPrefs.readFullKeyboardNumpadSide(from: defaults).rawValue
        )
        return KeyboardProfile(
            id: UUID(),
            name: name,
            kind: .custom,
            configuration: config,
            kioskPolicy: nil,
            schemaVersion: KeyboardProfile.currentSchemaVersion
        )
    }

    private static func make(id: UUID, name: String, kind: KeyboardProfile.Kind,
                             base: KeyboardProfile.Configuration) -> KeyboardProfile {
        KeyboardProfile(
            id: id,
            name: name,
            kind: kind,
            configuration: base,
            kioskPolicy: nil,
            schemaVersion: KeyboardProfile.currentSchemaVersion
        )
    }
}

extension KeyboardProfile.Configuration {
    /// Production defaults for the Standard built-in and as the base for other templates.
    /// Distinct from `testFixture` (which may intentionally differ for unit tests).
    static var productionDefaults: KeyboardProfile.Configuration {
        KeyboardProfile.Configuration(
            keyboardTypeRaw: KeyboardType.default.rawValue,
            themeRaw: KeyboardTheme.white.rawValue,
            automaticDarkMode: false,
            heightRaw: KeyboardHeightPreset.regular.rawValue,
            reversedMode: false,
            roundedCorners: false,
            grid: true,
            customKeyboardConfig: nil,
            handednessRaw: Handedness.right.rawValue,
            hapticsEnabled: true,
            soundEnabled: true,
            repurposeNextKey: true,
            clipboardHistoryEnabled: true,
            inlineCalculator: true,
            liveMathPreview: true,
            cursorControls: true,
            smartPackDefaulting: true,
            resultTapeEnabled: true,
            keyboardPageRaw: "numpad",
            qwertyPrimaryPackRaw: nil,
            packDisplayBehaviorRaw: PackDisplayBehavior.lastUsed.rawValue,
            qwertyPeriodComma: true,
            // Autocorrect stays OFF until measured gates pass (design §4 / release gates).
            qwertyAutocorrect: false,
            qwertySuggestions: true,
            qwertyDoubleSpacePeriod: true,
            qwertyLayoutModeRaw: QwertyLayoutMode.automatic.rawValue,
            numpadPlacementRaw: NumpadPlacement.automatic.rawValue,
            numpadWidthSizeRaw: NumpadWidthSize.full.rawValue,
            iPadQwertyLayoutRaw: IPadQwertyLayout.standard.rawValue,
            fullKeyboardNumpadSideRaw: FullKeyboardNumpadSide.right.rawValue
        )
    }
}
