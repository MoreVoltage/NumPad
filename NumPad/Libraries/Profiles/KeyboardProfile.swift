//
//  KeyboardProfile.swift
//  NumPad
//

import Foundation

struct KeyboardProfile: Codable, Equatable, Identifiable {
    static let currentSchemaVersion = 1

    enum Kind: String, Codable, CaseIterable {
        case standard, calculator, finance, inventory, writing, accessibility, kiosk, custom
    }

    var id: UUID
    var name: String
    var kind: Kind
    var configuration: Configuration
    var kioskPolicy: KioskPolicy?
    var schemaVersion: Int

    struct Configuration: Codable, Equatable {
        var keyboardTypeRaw: String
        var themeRaw: String
        var automaticDarkMode: Bool
        var heightRaw: String
        var reversedMode: Bool
        var roundedCorners: Bool
        var grid: Bool
        var customKeyboardConfig: CustomKeyboardConfig?
        var handednessRaw: String
        var hapticsEnabled: Bool
        var soundEnabled: Bool
        var repurposeNextKey: Bool
        var clipboardHistoryEnabled: Bool
        var inlineCalculator: Bool
        var liveMathPreview: Bool
        var cursorControls: Bool
        var smartPackDefaulting: Bool
        var resultTapeEnabled: Bool
        var keyboardPageRaw: String
        var qwertyPrimaryPackRaw: String?
        var packDisplayBehaviorRaw: String
        var qwertyPeriodComma: Bool
        var qwertyAutocorrect: Bool
        var qwertySuggestions: Bool
        var qwertyDoubleSpacePeriod: Bool
        var qwertyLayoutModeRaw: String
        var numpadPlacementRaw: String
    }


    enum ValidationError: Error, Equatable, CustomStringConvertible {
        case unsupportedSchema(Int)
        case invalidName
        case invalidKeyboardType(String)
        case invalidTheme(String)
        case invalidHeight(String)
        case invalidHandedness(String)
        case invalidKeyboardPage(String)
        case invalidPackDisplayBehavior(String)
        case invalidQwertyLayoutMode(String)
        case invalidNumpadPlacement(String)
        case invalidKioskTimeout(TimeInterval)
        case invalidPrimaryPack(String)
        case kioskPolicyKindMismatch

        var description: String {
            switch self {
            case .unsupportedSchema(let v): return "Unsupported profile schema version \(v)"
            case .invalidName: return "Profile name is empty or too long"
            case .invalidKeyboardType(let v): return "Invalid keyboard type '\(v)'"
            case .invalidTheme(let v): return "Invalid theme '\(v)'"
            case .invalidHeight(let v): return "Invalid height preset '\(v)'"
            case .invalidHandedness(let v): return "Invalid handedness '\(v)'"
            case .invalidKeyboardPage(let v): return "Invalid keyboard page '\(v)'"
            case .invalidPackDisplayBehavior(let v): return "Invalid pack display behavior '\(v)'"
            case .invalidQwertyLayoutMode(let v): return "Invalid QWERTY layout mode '\(v)'"
            case .invalidNumpadPlacement(let v): return "Invalid numpad placement '\(v)'"
            case .invalidKioskTimeout(let v): return "Kiosk timeout \(v) outside 30…3600 seconds"
            case .invalidPrimaryPack(let v): return "Invalid primary pack '\(v)'"
            case .kioskPolicyKindMismatch:
                return "Kiosk profile kind and session policy must be used together"
            }
        }
    }

    func validated() throws -> KeyboardProfile {
        guard schemaVersion == Self.currentSchemaVersion else {
            throw ValidationError.unsupportedSchema(schemaVersion)
        }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 80 else {
            throw ValidationError.invalidName
        }
        try configuration.validated()
        guard (kind == .kiosk) == (kioskPolicy != nil) else {
            throw ValidationError.kioskPolicyKindMismatch
        }
        if let policy = kioskPolicy {
            do {
                try policy.validated()
            } catch KioskPolicy.ValidationError.invalidTimeout(let v) {
                throw ValidationError.invalidKioskTimeout(v)
            }
        }
        var copy = self
        copy.name = trimmed
        return copy
    }
}

extension KeyboardProfile.Configuration {
    func validated() throws {
        guard
            let keyboardType = KeyboardType(rawValue: keyboardTypeRaw),
            ProfilePackPolicy.numpadFamily.contains(keyboardType)
        else {
            throw KeyboardProfile.ValidationError.invalidKeyboardType(keyboardTypeRaw)
        }
        guard KeyboardTheme(rawValue: themeRaw) != nil else {
            throw KeyboardProfile.ValidationError.invalidTheme(themeRaw)
        }
        guard KeyboardHeightPreset(rawValue: heightRaw) != nil else {
            throw KeyboardProfile.ValidationError.invalidHeight(heightRaw)
        }
        guard Handedness(rawValue: handednessRaw) != nil else {
            throw KeyboardProfile.ValidationError.invalidHandedness(handednessRaw)
        }
        guard keyboardPageRaw == "numpad" || keyboardPageRaw == "qwerty" else {
            throw KeyboardProfile.ValidationError.invalidKeyboardPage(keyboardPageRaw)
        }
        if !packDisplayBehaviorRaw.isEmpty {
            guard PackDisplayBehavior(rawValue: packDisplayBehaviorRaw) != nil else {
                throw KeyboardProfile.ValidationError.invalidPackDisplayBehavior(packDisplayBehaviorRaw)
            }
        }
        if let packRaw = qwertyPrimaryPackRaw {
            guard
                let pack = KeyboardType(rawValue: packRaw),
                QwertyPackFamily.members.contains(pack)
            else {
                throw KeyboardProfile.ValidationError.invalidPrimaryPack(packRaw)
            }
        }
        guard QwertyLayoutMode(rawValue: qwertyLayoutModeRaw) != nil else {
            throw KeyboardProfile.ValidationError.invalidQwertyLayoutMode(qwertyLayoutModeRaw)
        }
        guard NumpadPlacement(rawValue: numpadPlacementRaw) != nil else {
            throw KeyboardProfile.ValidationError.invalidNumpadPlacement(numpadPlacementRaw)
        }
    }
}

enum ProfilePackPolicy {
    static var numpadFamily: Set<KeyboardType> {
        Set([.default, .custom] + KeyboardType.packs)
    }
}

extension KeyboardProfile {
    static var testFixture: KeyboardProfile {
        KeyboardProfile(
            id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            name: "Test Profile",
            kind: .custom,
            configuration: .testFixture,
            kioskPolicy: nil,
            schemaVersion: currentSchemaVersion
        )
    }
}

extension KeyboardProfile.Configuration {
    static var testFixture: KeyboardProfile.Configuration {
        KeyboardProfile.Configuration(
            keyboardTypeRaw: KeyboardType.math.rawValue,
            themeRaw: KeyboardTheme.white.rawValue,
            automaticDarkMode: false,
            heightRaw: KeyboardHeightPreset.regular.rawValue,
            reversedMode: false,
            roundedCorners: true,
            grid: false,
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
            qwertyAutocorrect: true,
            qwertySuggestions: true,
            qwertyDoubleSpacePeriod: true,
            qwertyLayoutModeRaw: QwertyLayoutMode.automatic.rawValue,
            numpadPlacementRaw: NumpadPlacement.automatic.rawValue
        )
    }
}
