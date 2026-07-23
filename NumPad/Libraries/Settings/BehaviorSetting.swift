//
//  BehaviorSetting.swift
//  NumPad
//

import Foundation

/// Canonical catalog of operational behavior toggles that live outside the store.
enum BehaviorSetting: String, CaseIterable {
    case haptics
    case keyClickSound
    case repurposeNextKey
    case inlineCalculator
    case liveMathPreview
    case cursorControls
    case smartPackDefaulting
    case resultTape

    var title: String {
        switch self {
        case .haptics:
            return NSLocalizedString("Haptics", comment: "Toggle for haptic feedback")
        case .keyClickSound:
            return NSLocalizedString("Key Click Sound", comment: "Toggle for key click sound")
        case .repurposeNextKey:
            return NSLocalizedString("Repurpose Next Key", comment: "Toggle to repurpose the next keyboard key")
        case .inlineCalculator:
            return NSLocalizedString("Inline Calculator", comment: "Toggle for evaluating = expressions")
        case .liveMathPreview:
            return NSLocalizedString("Live Math Preview", comment: "Toggle for the compute-as-you-type result chip")
        case .cursorControls:
            return NSLocalizedString("Cursor Controls", comment: "Toggle for moving the caret from the keyboard")
        case .smartPackDefaulting:
            return NSLocalizedString("Smart Pack Defaulting", comment: "Toggle for auto-picking a pack to match the field")
        case .resultTape:
            return NSLocalizedString("Result Tape", comment: "Toggle for keeping recent calculator results")
        }
    }

    var imageName: String {
        switch self {
        case .haptics: return "tap"
        case .keyClickSound: return "switch"
        case .repurposeNextKey: return "keyboard"
        case .inlineCalculator: return "math2"
        case .liveMathPreview: return "math"
        case .cursorControls: return "next"
        case .smartPackDefaulting: return "keyboard"
        case .resultTape: return "switch"
        }
    }

    var isOn: Bool {
        switch self {
        case .haptics: return UserPrefs.hapticsEnabled
        case .keyClickSound: return UserPrefs.soundEnabled
        case .repurposeNextKey: return UserPrefs.repurposeNextKey
        case .inlineCalculator: return UserPrefs.inlineCalculator
        case .liveMathPreview: return UserPrefs.liveMathPreview
        case .cursorControls: return UserPrefs.cursorControls
        case .smartPackDefaulting: return UserPrefs.smartPackDefaulting
        case .resultTape: return UserPrefs.lastResultTape
        }
    }

    func set(_ value: Bool) {
        switch self {
        case .haptics: UserPrefs.hapticsEnabled = value
        case .keyClickSound: UserPrefs.soundEnabled = value
        case .repurposeNextKey: UserPrefs.repurposeNextKey = value
        case .inlineCalculator: UserPrefs.inlineCalculator = value
        case .liveMathPreview: UserPrefs.liveMathPreview = value
        case .cursorControls: UserPrefs.cursorControls = value
        case .smartPackDefaulting: UserPrefs.smartPackDefaulting = value
        case .resultTape: UserPrefs.lastResultTape = value
        }
        SettingsSync.post()
        Analytics.logEvent(
            name: "behavior_setting_changed",
            attributes: ["setting": rawValue, Analytics.ParameterValue: value]
        )
    }
}
