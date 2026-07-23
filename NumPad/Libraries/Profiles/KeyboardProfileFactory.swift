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
        make(id: BuiltInID.standard, name: "Standard", kind: .standard, base: .defaults)
    }

    static func calculator() -> KeyboardProfile {
        var config = KeyboardProfile.Configuration.defaults
        config.keyboardTypeRaw = KeyboardType.math.rawValue
        config.reversedMode = true
        config.heightRaw = KeyboardHeightPreset.regular.rawValue
        return make(id: BuiltInID.calculator, name: "Calculator", kind: .calculator, base: config)
    }

    static func finance() -> KeyboardProfile {
        var config = KeyboardProfile.Configuration.defaults
        config.keyboardTypeRaw = KeyboardType.finance.rawValue
        config.themeRaw = KeyboardTheme.teal.rawValue
        return make(id: BuiltInID.finance, name: "Finance", kind: .finance, base: config)
    }

    static func inventory() -> KeyboardProfile {
        var config = KeyboardProfile.Configuration.defaults
        config.keyboardTypeRaw = KeyboardType.units.rawValue
        config.grid = true
        config.roundedCorners = true
        return make(id: BuiltInID.inventory, name: "Inventory", kind: .inventory, base: config)
    }

    static func writing() -> KeyboardProfile {
        var config = KeyboardProfile.Configuration.defaults
        config.keyboardPageRaw = "qwerty"
        config.qwertySuggestions = true
        config.qwertyAutocorrect = true
        config.qwertyPeriodComma = true
        return make(id: BuiltInID.writing, name: "Writing", kind: .writing, base: config)
    }

    static func accessibility() -> KeyboardProfile {
        var config = KeyboardProfile.Configuration.defaults
        config.heightRaw = KeyboardHeightPreset.tall.rawValue
        config.roundedCorners = true
        config.grid = true
        config.hapticsEnabled = true
        config.soundEnabled = true
        config.themeRaw = KeyboardTheme.black.rawValue
        return make(id: BuiltInID.accessibility, name: "Accessibility", kind: .accessibility, base: config)
    }

    static func kiosk() -> KeyboardProfile {
        var config = KeyboardProfile.Configuration.defaults
        config.heightRaw = KeyboardHeightPreset.kiosk.rawValue
        config.themeRaw = KeyboardTheme.black.rawValue
        config.numpadPlacementRaw = NumpadPlacement.center.rawValue
        config.roundedCorners = true
        config.grid = true
        config.keyboardPageRaw = "numpad"
        config.clipboardHistoryEnabled = false
        config.resultTapeEnabled = true
        let policy = KeyboardProfile.KioskPolicy(
            inactivityTimeout: 120,
            resetPageAndPack: true,
            dismissOverlays: true,
            clearResultTape: true,
            clearClipboardHistory: true,
            requireAdministratorAuthentication: true
        )
        return KeyboardProfile(
            id: BuiltInID.kiosk,
            name: "Kiosk",
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
        let config = KeyboardProfile.Configuration(
            keyboardTypeRaw: defaults.string(forKey: Constants.selectedKeyboardType.rawValue) ?? KeyboardType.default.rawValue,
            themeRaw: defaults.string(forKey: Constants.selectedKeyboardTheme.rawValue) ?? KeyboardTheme.white.rawValue,
            automaticDarkMode: (defaults.object(forKey: Constants.automaticDarkMode.rawValue) as? Bool) ?? false,
            heightRaw: defaults.string(forKey: Constants.heightPreset.rawValue) ?? KeyboardHeightPreset.regular.rawValue,
            reversedMode: (defaults.object(forKey: Constants.reversedMode.rawValue) as? Bool) ?? false,
            roundedCorners: (defaults.object(forKey: Constants.roundedCorners.rawValue) as? Bool) ?? false,
            grid: (defaults.object(forKey: Constants.grid.rawValue) as? Bool) ?? false,
            customKeyboardConfig: custom,
            handednessRaw: defaults.string(forKey: Constants.handedness.rawValue) ?? Handedness.right.rawValue,
            hapticsEnabled: (defaults.object(forKey: Constants.hapticsEnabled.rawValue) as? Bool) ?? true,
            soundEnabled: (defaults.object(forKey: Constants.soundEnabled.rawValue) as? Bool) ?? true,
            repurposeNextKey: (defaults.object(forKey: Constants.repurposeNextKey.rawValue) as? Bool) ?? true,
            clipboardHistoryEnabled: (defaults.object(forKey: Constants.clipboardHistoryEnabled.rawValue) as? Bool) ?? true,
            inlineCalculator: (defaults.object(forKey: Constants.inlineCalculatorEnabled.rawValue) as? Bool) ?? true,
            liveMathPreview: (defaults.object(forKey: Constants.liveMathPreviewEnabled.rawValue) as? Bool) ?? true,
            cursorControls: (defaults.object(forKey: Constants.cursorControlsEnabled.rawValue) as? Bool) ?? true,
            smartPackDefaulting: (defaults.object(forKey: Constants.smartPackDefaultingEnabled.rawValue) as? Bool) ?? true,
            resultTapeEnabled: (defaults.object(forKey: Constants.lastResultTapeEnabled.rawValue) as? Bool) ?? true,
            keyboardPageRaw: defaults.string(forKey: Constants.keyboardPage.rawValue) ?? "numpad",
            qwertyPrimaryPackRaw: defaults.string(forKey: Constants.qwertyPrimaryPack.rawValue),
            packDisplayBehaviorRaw: defaults.string(forKey: Constants.packDisplayBehavior.rawValue) ?? PackDisplayBehavior.lastUsed.rawValue,
            qwertyPeriodComma: (defaults.object(forKey: Constants.qwertyPeriodComma.rawValue) as? Bool) ?? true,
            qwertyAutocorrect: (defaults.object(forKey: Constants.qwertyAutocorrectEnabled.rawValue) as? Bool) ?? true,
            qwertySuggestions: (defaults.object(forKey: Constants.qwertySuggestionsEnabled.rawValue) as? Bool) ?? true,
            qwertyDoubleSpacePeriod: (defaults.object(forKey: Constants.qwertyDoubleSpacePeriodEnabled.rawValue) as? Bool) ?? true,
            qwertyLayoutModeRaw: defaults.string(forKey: Constants.qwertyLayoutMode.rawValue) ?? QwertyLayoutMode.automatic.rawValue,
            numpadPlacementRaw: defaults.string(forKey: Constants.numpadPlacement.rawValue) ?? NumpadPlacement.automatic.rawValue
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
    static var defaults: KeyboardProfile.Configuration {
        .testFixture
    }
}
