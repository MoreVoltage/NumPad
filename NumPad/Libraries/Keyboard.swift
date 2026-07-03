//
//  Keyboard.swift
//  NumPad
//
//  Created by Lasha Efremidze on 3/24/17.
//  Copyright © 2017 MoreVoltage. All rights reserved.
//

import UIKit

struct Keyboard {
    
    static var isKeyboardEnabled: Bool {
        guard let id = bundleIdentifier else { return false }
        return !id.isEmpty
    }
    
    static var bundleIdentifier: String? {
        guard
            let id = Bundle.main.bundleIdentifier,
            let keyboards = UserDefaults.standard.array(forKey: "AppleKeyboards") as? [String]
        else { return nil }
        return keyboards.first { $0.hasPrefix(id) }
    }
    
    @UserDefault(key: Constants.reversedMode.rawValue, defaultValue: false, userDefaults: .group)
    static var isReversedMode: Bool
    
    @UserDefault(key: Constants.roundedCorners.rawValue, defaultValue: false, userDefaults: .group)
    static var hasRoundedCorners: Bool

    @UserDefault(key: Constants.grid.rawValue, defaultValue: true, userDefaults: .group)
    static var hasGrid: Bool
    
}

/// User-selectable keyboard height on iPhone AND iPad (2.0 — the previous iPad system-height-only
/// guard was self-imposed, not an App Review requirement). The preset sets the pre-clamp base
/// height, per idiom (iPad's system keyboard is already ~264pt portrait / ~352pt landscape, so it
/// needs taller values than iPhone to read as bigger); the existing clamp (min 220 portrait / 160
/// landscape, max 50% of the container) still applies on both idioms. `.kiosk` is a Pro-gated extra
/// -tall preset (`Monetization.isKioskHeightEntitled`); a persisted-but-unentitled selection falls
/// back to `.tall` via `effective(stored:kioskEntitled:)`.
enum KeyboardHeightPreset: String, CaseIterable {
    case small, regular, tall, kiosk

    /// Pre-clamp base height for `idiom`. Kiosk has no iPad-distinct meaning on iPhone (the UI never
    /// lets iPhone users select it) so it just mirrors Tall there.
    func baseHeight(idiom: UIUserInterfaceIdiom) -> CGFloat {
        switch idiom {
        case .pad:
            switch self {
            case .small: return 300
            case .regular: return 350
            case .tall: return 420
            case .kiosk: return 500
            }
        default:
            switch self {
            case .small: return 260
            case .regular: return 300
            case .tall, .kiosk: return 340
            }
        }
    }

    var name: String {
        switch self {
        case .small: return NSLocalizedString("Small", comment: "Keyboard height preset name")
        case .regular: return NSLocalizedString("Default", comment: "Keyboard height preset name")
        case .tall: return NSLocalizedString("Tall", comment: "Keyboard height preset name")
        case .kiosk: return NSLocalizedString("Kiosk", comment: "Keyboard height preset name")
        }
    }

    @UserDefault(key: Constants.heightPreset.rawValue, defaultValue: KeyboardHeightPreset.regular.rawValue, userDefaults: .group)
    private static var _selected: String

    static var selected: KeyboardHeightPreset {
        get { return KeyboardHeightPreset(rawValue: _selected) ?? .regular }
        set { _selected = newValue.rawValue }
    }

    /// The preset actually used for sizing: `stored` unless it's the Pro-gated `.kiosk` and the
    /// user isn't entitled (lapsed Pro, or an iCloud-synced value from another device/account), in
    /// which case it falls back to `.tall`. Pure function — no UserDefaults/StoreKit — so it's
    /// unit-testable in isolation.
    static func effective(stored: KeyboardHeightPreset, kioskEntitled: Bool) -> KeyboardHeightPreset {
        guard stored == .kiosk, !kioskEntitled else { return stored }
        return .tall
    }

    /// The clamp applied to every preset's base height: never below `minHeight`, never above the
    /// larger of `minHeight` and `maxHeightCap` (the caller-computed 50%-of-container cap). Pure —
    /// no UIKit/UserDefaults — so the clamp math is unit-testable without a live view hierarchy.
    static func clampedHeight(base: CGFloat, minHeight: CGFloat, maxHeightCap: CGFloat) -> CGFloat {
        let maxHeight = max(maxHeightCap, minHeight)
        return max(minHeight, min(maxHeight, base))
    }
}

enum KeyboardType: String {
    case `default`, math, math2, finance, symbols, programmer, tax, custom
    // 2.0 packs (Phase 2). `programmerPlus` is the extended programmer pack; the rest are new domains.
    // `datetime` and `international` are computed packs wired in later sub-phases.
    case units, scientific, datetime, business, international, programmerPlus

    // NOTE: `.tax` is intentionally not a selectable pack — its old pack row was removed (keys had
    // no handler and inserted literal text). Tax/Tip lives in the long-press "%" overlay instead.
    // The case remains so a stale persisted `.tax` selection still decodes (falls back to no pack row).
    static var packs: [KeyboardType] {
        return [.math, .math2, .finance, .symbols, .programmer, .datetime]
    }
    
    var name: String {
        switch self {
        case .default:
            return NSLocalizedString("Default", comment: "Keyboard type name for the default keyboard")
        case .math, .math2:
            return NSLocalizedString("Math", comment: "Keyboard type name for the math keyboard")
        case .finance:
            return NSLocalizedString("Finance", comment: "Keyboard type name for the finance keyboard")
        case .symbols:
            return NSLocalizedString("Symbols & Science", comment: "Keyboard type name for the symbols keyboard")
        case .programmer:
            return NSLocalizedString("Programmer", comment: "Keyboard type name for the programmer keyboard")
        case .tax:
            return NSLocalizedString("Tax/Tips", comment: "Keyboard type name for the tax/tips keyboard")
        case .custom:
            return NSLocalizedString("Custom", comment: "Keyboard type name for the user-defined custom keyboard pack")
        case .units:
            return NSLocalizedString("Units & Conversion", comment: "Keyboard type name for the units and conversion pack")
        case .scientific:
            return NSLocalizedString("Scientific", comment: "Keyboard type name for the scientific pack")
        case .datetime:
            return NSLocalizedString("Date & Time", comment: "Keyboard type name for the date and time pack")
        case .business:
            return NSLocalizedString("Business", comment: "Keyboard type name for the business and accounting pack")
        case .international:
            return NSLocalizedString("International", comment: "Keyboard type name for the international and formatting pack")
        case .programmerPlus:
            return NSLocalizedString("Programmer+", comment: "Keyboard type name for the extended programmer pack")
        }
    }
    
    @UserDefault(key: Constants.selectedKeyboardType.rawValue, defaultValue: nil, userDefaults: .group)
    private static var _selected: String?
    static var selected: KeyboardType {
        get { return _selected.flatMap(KeyboardType.init) ?? .default }
        set { _selected = newValue.rawValue }
    }
    
    var isSelected: Bool {
        return KeyboardType.selected == self
    }
    
    mutating func toggleMath() {
        switch self {
        case .math:
            self = .math2
        case .math2:
            self = .math
        default: break
        }
    }
}

enum KeyboardTheme: String, CaseIterable {
    case white, black, red, pink, purple, deepPurple, indigo, blue, lightBlue, teal, green, lightGreen, lime, yellow, amber, orange, deepOrange
    
    var name: String {
        switch self {
        case .deepPurple: return NSLocalizedString("Deep Purple", comment: "")
        case .lightBlue: return NSLocalizedString("Light Blue", comment: "")
        case .lightGreen: return NSLocalizedString("Light Green", comment: "")
        case .deepOrange: return NSLocalizedString("Deep Orange", comment: "")
        default: return NSLocalizedString(rawValue.capitalized, comment: "")
        }
    }
    
    var color: UIColor {
        switch self {
        case .white: return .white
        case .black: return .black
        case .red: return Color.red
        case .pink: return Color.pink
        case .purple: return Color.purple
        case .deepPurple: return Color.deepPurple
        case .indigo: return Color.indigo
        case .blue: return Color.blue
        case .lightBlue: return Color.lightBlue
        case .teal: return Color.teal
        case .green: return Color.green
        case .lightGreen: return Color.lightGreen
        case .lime: return Color.lime
        case .yellow: return Color.yellow
        case .amber: return Color.amber
        case .orange: return Color.orange
        case .deepOrange: return Color.deepOrange
        }
    }
    
    @UserDefault(key: Constants.selectedKeyboardTheme.rawValue, defaultValue: KeyboardTheme.white.rawValue, userDefaults: .group)
    private static var _selected: String
    
    static var selected: KeyboardTheme {
        get { return KeyboardTheme(rawValue: _selected) ?? .white }
        set { _selected = newValue.rawValue }
    }
    
    var isSelected: Bool {
        return KeyboardTheme.selected == self
    }
    
    static var selectedOrAutomatic: KeyboardTheme {
        if automaticDarkMode {
            return Theme.isDarkMode ? .black : .white
        }
        return selected
    }
    
    @UserDefault(key: Constants.automaticDarkMode.rawValue, defaultValue: false, userDefaults: .group)
    static var automaticDarkMode: Bool
}
