//
//  StudioSettingsWriter.swift
//  NumPad
//

import Foundation

enum StudioPreviewContext: String {
    case numpad
    case qwerty
    case lastUsedPage

    static let requestedNotification = Notification.Name("StudioPreviewContext.requested")

    static func request(_ context: StudioPreviewContext) {
        NotificationCenter.default.post(
            name: requestedNotification,
            object: context
        )
    }
}

extension NumpadWidthSize {
    /// Mirrors the production fraction in the choice's miniature horizontal bar.
    var studioSampleFraction: CGFloat { fraction }

    var studioDisplayName: String {
        switch self {
        case .compact: return NSLocalizedString("Compact", comment: "iPad numpad width")
        case .comfortable: return NSLocalizedString("Comfortable", comment: "iPad numpad width")
        case .medium: return NSLocalizedString("Medium", comment: "iPad numpad width")
        case .wide: return NSLocalizedString("Wide", comment: "iPad numpad width")
        case .full: return NSLocalizedString("Full", comment: "iPad numpad width")
        }
    }
}

extension IPadQwertyLayout {
    var studioDisplayName: String {
        self == .standard
            ? NSLocalizedString("Standard", comment: "iPad QWERTY layout")
            : NSLocalizedString("Full Keyboard", comment: "iPad QWERTY layout")
    }
}

extension FullKeyboardNumpadSide {
    var studioDisplayName: String {
        NSLocalizedString(rawValue.capitalized, comment: "Full keyboard numpad side")
    }
}

extension Notification.Name {
    static let studioSettingsDidChange = Notification.Name("StudioSettingsWriter.didChange")
}

/// A narrow, injectable boundary for settings changed from Keyboard Studio.
/// Every method performs one shared-defaults mutation followed by exactly one cross-process sync.
struct StudioSettingsWriter {
    private let defaults: UserDefaults
    private let postSettingsSync: () -> Void
    private let postLocalRefresh: () -> Void

    init(
        defaults: UserDefaults = .group,
        postSettingsSync: @escaping () -> Void = { SettingsSync.post() },
        postLocalRefresh: @escaping () -> Void = {
            NotificationCenter.default.post(name: .studioSettingsDidChange, object: nil)
        }
    ) {
        self.defaults = defaults
        self.postSettingsSync = postSettingsSync
        self.postLocalRefresh = postLocalRefresh
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
    func setNumpadWidthSize(_ value: NumpadWidthSize) { write(value.rawValue, key: .numpadWidthSize) }
    func setIPadQwertyLayout(_ value: IPadQwertyLayout) { write(value.rawValue, key: .iPadQwertyLayout) }
    func setFullKeyboardNumpadSide(_ value: FullKeyboardNumpadSide) { write(value.rawValue, key: .fullKeyboardNumpadSide) }

    private func write(_ value: Any, key: Constants) {
        defaults.set(value, forKey: key.rawValue)
        postLocalRefresh()
        postSettingsSync()
    }
}
