//
//  StudioSettingsWriter.swift
//  NumPad
//

import Foundation

/// A narrow, injectable boundary for settings changed from Keyboard Studio.
/// Every method performs one shared-defaults mutation followed by exactly one cross-process sync.
struct StudioSettingsWriter {
    private let defaults: UserDefaults
    private let postSettingsSync: () -> Void

    init(
        defaults: UserDefaults = .group,
        postSettingsSync: @escaping () -> Void = { SettingsSync.post() }
    ) {
        self.defaults = defaults
        self.postSettingsSync = postSettingsSync
    }

    @discardableResult
    func selectKeySet(_ choice: StudioKeySetCatalog.Choice, currentPack: KeyboardType) -> Bool {
        guard !choice.isLocked else { return false }
        let pack: KeyboardType
        switch choice.id {
        case .numbers: pack = .default
        case .calculations:
            pack = currentPack == .math ? .math2 : .math
        case .prices: pack = .finance
        case .measurements: pack = .units
        case .dateAndTime: pack = .datetime
        case .symbols: pack = .symbols
        case .programming: pack = .programmer
        }
        write(pack.rawValue, key: .selectedKeyboardType)
        return true
    }

    func setTheme(_ theme: KeyboardTheme) { write(theme.rawValue, key: .selectedKeyboardTheme) }
    func setAutomaticDarkMode(_ enabled: Bool) { write(enabled, key: .automaticDarkMode) }
    func setRoundedCorners(_ enabled: Bool) { write(enabled, key: .roundedCorners) }
    func setGrid(_ enabled: Bool) { write(enabled, key: .grid) }
    func setHeight(_ preset: KeyboardHeightPreset) { write(preset.rawValue, key: .heightPreset) }
    func setReversedMode(_ enabled: Bool) { write(enabled, key: .reversedMode) }
    func setHapticsEnabled(_ enabled: Bool) { write(enabled, key: .hapticsEnabled) }
    func setSoundEnabled(_ enabled: Bool) { write(enabled, key: .soundEnabled) }
    func setCursorControlsEnabled(_ enabled: Bool) { write(enabled, key: .cursorControlsEnabled) }
    func setLettersPageEnabled(_ enabled: Bool) { write(enabled ? "qwerty" : "numpad", key: .keyboardPage) }
    func setAutocorrectEnabled(_ enabled: Bool) { write(enabled, key: .qwertyAutocorrectEnabled) }
    func setSuggestionsEnabled(_ enabled: Bool) { write(enabled, key: .qwertySuggestionsEnabled) }
    func setDoubleSpacePeriodEnabled(_ enabled: Bool) { write(enabled, key: .qwertyDoubleSpacePeriodEnabled) }
    func setPeriodCommaEnabled(_ enabled: Bool) { write(enabled, key: .qwertyPeriodComma) }

    private func write(_ value: Any, key: Constants) {
        defaults.set(value, forKey: key.rawValue)
        postSettingsSync()
    }
}
