//
//  KeyboardLayoutPreferences.swift
//  NumPad
//

import Foundation

enum QwertyLayoutMode: String, Codable, CaseIterable {
    case automatic
    case centered
    case split
    case compactLeft
    case compactRight
}

enum NumpadPlacement: String, Codable, CaseIterable {
    case automatic
    case center
    case left
    case right
    case fullWidth
}

enum NumpadWidthSize: String, Codable, CaseIterable {
    case compact
    case comfortable
    case medium
    case wide
    case full

    static let defaultValue: Self = .full

    var fraction: CGFloat {
        switch self {
        case .compact: return 0.60
        case .comfortable: return 0.70
        case .medium: return 0.80
        case .wide: return 0.90
        case .full: return 1.00
        }
    }

    /// Maps pre-width-pref installs onto the five-width model.
    ///
    /// Soft landing: only legacy `.fullWidth` becomes `.full`. Every other placement
    /// (automatic / center / left / right) maps to **`.medium` (80%)**, not `.compact`
    /// (60%). Compact-as-default produced empty rails and a phone-in-a-desert feel on
    /// 11–13" iPads for anyone who never chose full-bleed — the majority of automatic
    /// users. Medium preserves a centered pad without the hostile shrink.
    static func migrated(from legacy: NumpadPlacement) -> Self {
        legacy == .fullWidth ? .full : .medium
    }
}

enum IPadQwertyLayout: String, Codable, CaseIterable {
    case standard
    case full

    static let defaultValue: Self = .standard

    static func migrated(from legacy: QwertyLayoutMode) -> Self {
        .standard
    }
}

enum FullKeyboardNumpadSide: String, Codable, CaseIterable {
    case left
    case right

    static let defaultValue: Self = .right
}
