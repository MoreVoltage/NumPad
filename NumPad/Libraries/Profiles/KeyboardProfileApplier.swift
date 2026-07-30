//
//  KeyboardProfileApplier.swift
//  NumPad
//
//  Atomic profile application: validate → resolve fallbacks → write all settings
//  (including clearing omitted custom config) → persist active identity → notify once.
//  Failures restore prior settings and never leave a partially applied keyboard.
//

import Foundation

/// Entitlement snapshot passed into profile application. Mirrors `Monetization` as the SoT —
/// every à-la-carte pack is gated via `ownedPackProductIDs` + `Monetization.isPackLocked`.
struct ProfileEntitlements: Equatable {
    let paywallEnabled: Bool
    let proEntitled: Bool
    let kioskHeightEntitled: Bool
    let customKeyboardEntitled: Bool
    let fullKeyboardEntitled: Bool
    let ownedPackProductIDs: Set<String>

    func isPackLocked(_ pack: KeyboardType) -> Bool {
        guard paywallEnabled else { return false }
        return Monetization.isPackLocked(
            pack,
            proEntitled: proEntitled,
            ownedPackProductIDs: ownedPackProductIDs
        )
    }

    func isThemeLocked(_ theme: KeyboardTheme) -> Bool {
        guard paywallEnabled, !proEntitled else { return false }
        return theme.isPremium
    }

    /// Live entitlements from `Monetization` (including legacy finance ownership).
    static func live() -> ProfileEntitlements {
        var owned = Monetization.ownedPackProductIDs
        if Monetization.isFinancePackPurchased,
           let finance = ProductCatalog.packProductID(for: .finance) {
            owned.insert(finance)
        }
        return ProfileEntitlements(
            paywallEnabled: Monetization.paywallEnabled,
            proEntitled: Monetization.isProEntitled,
            kioskHeightEntitled: Monetization.isKioskHeightEntitled,
            customKeyboardEntitled: Monetization.isCustomKeyboardEntitled,
            fullKeyboardEntitled: Monetization.isFullKeyboardEntitled,
            ownedPackProductIDs: owned
        )
    }
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
    /// The configuration that was actually written (after entitlement fallbacks).
    let appliedConfiguration: KeyboardProfile.Configuration
}

enum ProfileApplyError: Error, Equatable, CustomStringConvertible {
    case validation(KeyboardProfile.ValidationError)
    case customKeyboard(CustomKeyboardProfileValidation.Error)
    case kioskModeLocked
    case persistence(String)

    var description: String {
        switch self {
        case .validation(let e): return e.description
        case .customKeyboard(let e): return e.description
        case .kioskModeLocked: return "Kiosk mode requires Pro"
        case .persistence(let m): return m
        }
    }
}

struct KeyboardProfileApplier {
    let defaults: UserDefaults
    var notify: () -> Void = { SettingsSync.post() }
    /// Optional store used to keep the active profile identity consistent with settings writes.
    var store: KeyboardProfileStore?
    /// Injectable Remote Config mirror so apply and probe use the keyboard's complete QWERTY
    /// availability rule while unit tests remain independent from app-group state.
    var qwertyRemoteEnabled: () -> Bool = { FeatureFlags.fullKeyboardRemoteEnabled }

    static let liveSettingKeys: [String] = [
        Constants.selectedKeyboardType.rawValue,
        Constants.selectedKeyboardTheme.rawValue,
        Constants.automaticDarkMode.rawValue,
        Constants.heightPreset.rawValue,
        Constants.reversedMode.rawValue,
        Constants.roundedCorners.rawValue,
        Constants.grid.rawValue,
        Constants.customKeyboardConfig.rawValue,
        Constants.handedness.rawValue,
        Constants.hapticsEnabled.rawValue,
        Constants.soundEnabled.rawValue,
        Constants.repurposeNextKey.rawValue,
        Constants.clipboardHistoryEnabled.rawValue,
        Constants.inlineCalculatorEnabled.rawValue,
        Constants.liveMathPreviewEnabled.rawValue,
        Constants.cursorControlsEnabled.rawValue,
        Constants.smartPackDefaultingEnabled.rawValue,
        Constants.lastResultTapeEnabled.rawValue,
        Constants.keyboardPage.rawValue,
        Constants.qwertyPrimaryPack.rawValue,
        Constants.packDisplayBehavior.rawValue,
        Constants.qwertyPeriodComma.rawValue,
        Constants.qwertyAutocorrectEnabled.rawValue,
        Constants.qwertySuggestionsEnabled.rawValue,
        Constants.qwertyDoubleSpacePeriodEnabled.rawValue,
        Constants.qwertyLayoutMode.rawValue,
        Constants.numpadPlacement.rawValue
    ]
    /// Every app-group setting mutated during profile application. Rollback wrappers such as
    /// Cloud Sync must snapshot this set, not only the durable keyboard configuration.
    static let transactionSettingKeys: [String] = liveSettingKeys + [
        Constants.kioskLastActivity.rawValue,
        Constants.kioskLastActivityProfileID.rawValue
    ]

    func apply(_ profile: KeyboardProfile, entitlements: ProfileEntitlements) throws -> ApplyResult {
        let validated: KeyboardProfile
        do {
            validated = try profile.validated()
        } catch let error as KeyboardProfile.ValidationError {
            throw ProfileApplyError.validation(error)
        }
        guard KioskModeAccess.allows(validated, proEntitled: entitlements.proEntitled) else {
            throw ProfileApplyError.kioskModeLocked
        }

        if let custom = validated.configuration.customKeyboardConfig {
            do {
                try CustomKeyboardProfileValidation.validate(custom)
            } catch let error as CustomKeyboardProfileValidation.Error {
                throw ProfileApplyError.customKeyboard(error)
            }
        }

        var config = validated.configuration
        let fallbacks = resolveFallbacks(config: &config, entitlements: entitlements)

        // Precompute the complete desired write set before mutating anything.
        let desired = desiredSettings(from: config)
        let profileStore = store ?? KeyboardProfileStore(defaults: defaults)
        let keysToSnapshot = Self.transactionSettingKeys + [
            profileStore.profilesKey,
            profileStore.activeIDKey
        ]
        let previous = snapshot(keys: keysToSnapshot)

        do {
            var changed: Set<String> = []

            for (key, value) in desired {
                if write(key, value, into: &changed) { /* tracked */ }
            }

            // Nil custom config must clear the live custom keyboard — omitted ≠ leave-in-place.
            var customStore = CustomKeyboardStore(defaults: defaults)
            customStore.onChange = {}
            if let custom = config.customKeyboardConfig {
                if customStore.load() != custom {
                    customStore.save(custom)
                    changed.insert(Constants.customKeyboardConfig.rawValue)
                }
            } else if defaults.object(forKey: Constants.customKeyboardConfig.rawValue) != nil {
                customStore.clear()
                changed.insert(Constants.customKeyboardConfig.rawValue)
            }

            // Applying any profile starts a new kiosk-session identity. Clear both halves of the
            // coarse clock transactionally so leaving and later re-entering the same kiosk profile
            // cannot inherit an expired timestamp from its prior session.
            for key in [
                Constants.kioskLastActivity.rawValue,
                Constants.kioskLastActivityProfileID.rawValue
            ] where defaults.object(forKey: key) != nil {
                defaults.removeObject(forKey: key)
                changed.insert(key)
            }

            defaults.set(validated.id.uuidString, forKey: Constants.activeKeyboardProfileID.rawValue)
            changed.insert(Constants.activeKeyboardProfileID.rawValue)

            // Persist active identity on the profile blob without mutating authored config for fallbacks.
            try persistActiveIdentity(validated)

            notify()
            return ApplyResult(
                changedKeys: changed,
                fallbacks: fallbacks,
                appliedConfiguration: config
            )
        } catch let error as ProfileApplyError {
            restore(previous)
            throw error
        } catch {
            restore(previous)
            throw ProfileApplyError.persistence(String(describing: error))
        }
    }

    private func persistActiveIdentity(_ validated: KeyboardProfile) throws {
        let profileStore = store ?? KeyboardProfileStore(defaults: defaults)
        var snap = profileStore.load()
        if let idx = snap.profiles.firstIndex(where: { $0.id == validated.id }) {
            snap.profiles[idx] = validated
        } else {
            snap.profiles.append(validated)
        }
        snap.activeProfileID = validated.id
        do {
            try profileStore.save(snap)
        } catch {
            throw ProfileApplyError.persistence(String(describing: error))
        }
    }

    /// Validates and resolves entitlement fallbacks without writing settings. Used by dashboards
    /// and readiness probes so viewing status never mutates the live keyboard.
    func probe(_ profile: KeyboardProfile, entitlements: ProfileEntitlements) throws -> ApplyResult {
        let validated: KeyboardProfile
        do {
            validated = try profile.validated()
        } catch let error as KeyboardProfile.ValidationError {
            throw ProfileApplyError.validation(error)
        }
        if let custom = validated.configuration.customKeyboardConfig {
            do {
                try CustomKeyboardProfileValidation.validate(custom)
            } catch let error as CustomKeyboardProfileValidation.Error {
                throw ProfileApplyError.customKeyboard(error)
            }
        }
        var config = validated.configuration
        let fallbacks = resolveFallbacks(config: &config, entitlements: entitlements)
        return ApplyResult(changedKeys: [], fallbacks: fallbacks, appliedConfiguration: config)
    }

    // MARK: - Fallbacks (do not mutate the saved profile)

    func resolveFallbacks(
        config: inout KeyboardProfile.Configuration,
        entitlements: ProfileEntitlements
    ) -> [ProfileFallback] {
        var fallbacks: [ProfileFallback] = []

        if config.heightRaw == KeyboardHeightPreset.kiosk.rawValue, !entitlements.kioskHeightEntitled {
            config.heightRaw = KeyboardHeightPreset.tall.rawValue
            fallbacks.append(.heightKioskToTall)
        }

        if let type = KeyboardType(rawValue: config.keyboardTypeRaw),
           entitlements.isPackLocked(type) {
            fallbacks.append(.packLocked(config.keyboardTypeRaw))
            config.keyboardTypeRaw = KeyboardType.default.rawValue
        }

        if config.customKeyboardConfig != nil, !entitlements.customKeyboardEntitled {
            fallbacks.append(.customKeyboardLocked)
            config.customKeyboardConfig = nil
        }

        let qwertyAvailable = FeatureFlags.qwertyPageAvailable(
            remoteEnabled: qwertyRemoteEnabled(),
            entitled: entitlements.fullKeyboardEntitled
        )
        if config.keyboardPageRaw == "qwerty", !qwertyAvailable {
            fallbacks.append(.qwertyPageLocked)
            config.keyboardPageRaw = "numpad"
        }

        if let theme = KeyboardTheme(rawValue: config.themeRaw),
           entitlements.isThemeLocked(theme) {
            fallbacks.append(.themePremiumToWhite(config.themeRaw))
            config.themeRaw = KeyboardTheme.white.rawValue
        }

        return fallbacks
    }

    private func desiredSettings(from config: KeyboardProfile.Configuration) -> [String: Any] {
        var map: [String: Any] = [
            Constants.selectedKeyboardType.rawValue: config.keyboardTypeRaw,
            Constants.selectedKeyboardTheme.rawValue: config.themeRaw,
            Constants.automaticDarkMode.rawValue: config.automaticDarkMode,
            Constants.heightPreset.rawValue: config.heightRaw,
            Constants.reversedMode.rawValue: config.reversedMode,
            Constants.roundedCorners.rawValue: config.roundedCorners,
            Constants.grid.rawValue: config.grid,
            Constants.handedness.rawValue: config.handednessRaw,
            Constants.hapticsEnabled.rawValue: config.hapticsEnabled,
            Constants.soundEnabled.rawValue: config.soundEnabled,
            Constants.repurposeNextKey.rawValue: config.repurposeNextKey,
            Constants.clipboardHistoryEnabled.rawValue: config.clipboardHistoryEnabled,
            Constants.inlineCalculatorEnabled.rawValue: config.inlineCalculator,
            Constants.liveMathPreviewEnabled.rawValue: config.liveMathPreview,
            Constants.cursorControlsEnabled.rawValue: config.cursorControls,
            Constants.smartPackDefaultingEnabled.rawValue: config.smartPackDefaulting,
            Constants.lastResultTapeEnabled.rawValue: config.resultTapeEnabled,
            Constants.keyboardPage.rawValue: config.keyboardPageRaw,
            Constants.packDisplayBehavior.rawValue: config.packDisplayBehaviorRaw,
            Constants.qwertyPeriodComma.rawValue: config.qwertyPeriodComma,
            Constants.qwertyAutocorrectEnabled.rawValue: config.qwertyAutocorrect,
            Constants.qwertySuggestionsEnabled.rawValue: config.qwertySuggestions,
            Constants.qwertyDoubleSpacePeriodEnabled.rawValue: config.qwertyDoubleSpacePeriod,
            Constants.qwertyLayoutMode.rawValue: config.qwertyLayoutModeRaw,
            Constants.numpadPlacement.rawValue: config.numpadPlacementRaw
        ]
        if let primary = config.qwertyPrimaryPackRaw {
            map[Constants.qwertyPrimaryPack.rawValue] = primary
        } else {
            map[Constants.qwertyPrimaryPack.rawValue] = NSNull()
        }
        return map
    }

    @discardableResult
    private func write(_ key: String, _ value: Any, into changed: inout Set<String>) -> Bool {
        let previous = defaults.object(forKey: key)
        if value is NSNull {
            if previous == nil { return false }
            defaults.removeObject(forKey: key)
            changed.insert(key)
            return true
        }
        if let prev = previous as? NSObject, let new = value as? NSObject, prev.isEqual(new) {
            return false
        }
        defaults.set(value, forKey: key)
        changed.insert(key)
        return true
    }

    private func snapshot(keys: [String]) -> [String: Any?] {
        Dictionary(uniqueKeysWithValues: keys.map { ($0, defaults.object(forKey: $0)) })
    }

    func restore(_ previous: [String: Any?]) {
        for (key, value) in previous {
            if let value {
                defaults.set(value, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }
    }
}

// MARK: - Custom keyboard structural validation (import / apply)

enum CustomKeyboardProfileValidation {
    enum Error: Swift.Error, Equatable, CustomStringConvertible {
        case unsupportedSchema(Int)
        case invalidName
        case topRowTooLong(Int)
        case columnTooLong(String, Int)
        case tokenTooLong(String)
        case unsupportedToken(String)

        var description: String {
            switch self {
            case .unsupportedSchema(let v): return "Unsupported custom keyboard schema \(v)"
            case .invalidName: return "Custom keyboard name is empty or too long"
            case .topRowTooLong(let n): return "Top row has \(n) keys; max \(CustomKeyboardEditorModel.topRowCapacity)"
            case .columnTooLong(let name, let n): return "\(name) has \(n) keys; max \(CustomKeyboardEditorModel.columnCapacity)"
            case .tokenTooLong(let t): return "Token '\(t)' exceeds \(CustomKeys.maxTokenLength) characters"
            case .unsupportedToken(let t): return "Unsupported custom key token '\(t)'"
            }
        }
    }

    static func validate(_ config: CustomKeyboardConfig) throws {
        guard config.schemaVersion == CustomKeyboardConfig.currentSchema else {
            throw Error.unsupportedSchema(config.schemaVersion)
        }
        let trimmed = config.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 80 else {
            throw Error.invalidName
        }
        if let top = config.topRow {
            guard top.count <= CustomKeyboardEditorModel.topRowCapacity else {
                throw Error.topRowTooLong(top.count)
            }
            try top.forEach(validateToken)
        }
        if let col1 = config.column1 {
            guard col1.count <= CustomKeyboardEditorModel.columnCapacity else {
                throw Error.columnTooLong("Column 1", col1.count)
            }
            try col1.forEach(validateToken)
        }
        if let col2 = config.column2 {
            guard col2.count <= CustomKeyboardEditorModel.columnCapacity else {
                throw Error.columnTooLong("Column 2", col2.count)
            }
            try col2.forEach(validateToken)
        }
    }

    private static func validateToken(_ raw: String) throws {
        guard !raw.isEmpty else { return }
        if CustomKeys.palette.contains(raw) { return }
        if DateTimeTokens.token(fromKey: raw) != nil { return }
        if raw.hasPrefix("{"), raw.hasSuffix("}") {
            throw Error.unsupportedToken(raw)
        }
        guard raw.count <= CustomKeys.maxTokenLength else {
            throw Error.tokenTooLong(raw)
        }
    }
}
