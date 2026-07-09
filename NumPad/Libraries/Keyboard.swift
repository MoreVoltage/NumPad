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

    /// Whether NumPad Type (the full-QWERTY extension) specifically is enabled in Settings —
    /// `isKeyboardEnabled` above is satisfied by either keyboard. Pure on its input for testing.
    static func isTypeKeyboardEnabled(in keyboards: [String]?) -> Bool {
        keyboards?.contains { $0.hasSuffix(".KeyboardType") } == true
    }

    static var isTypeKeyboardEnabled: Bool {
        isTypeKeyboardEnabled(in: UserDefaults.standard.array(forKey: "AppleKeyboards") as? [String])
    }

    /// Whether the numpad draws its own dedicated keyboard-switch (globe) key.
    ///
    /// With the pack-switch key repurposed to cycle packs (the default) it no longer switches
    /// keyboards, so the globe must come back in two cases: Home-button devices, where iOS
    /// draws no system globe affordance at all, and any device where the sibling NumPad Type
    /// keyboard is enabled — otherwise the numpad offers pack swapping but no button over to
    /// the full keyboard. With repurposing off the pack-switch key already behaves as the
    /// system globe, so a second one is never drawn.
    static func numpadNeedsDedicatedSwitchKey(systemNeedsSwitchKey: Bool,
                                              repurposeNextKey: Bool,
                                              typeKeyboardEnabled: Bool) -> Bool {
        repurposeNextKey && (systemNeedsSwitchKey || typeKeyboardEnabled)
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

    /// iPad's pinch-to-float mini keyboard: narrow (no room for a custom height — it's meant to be
    /// phone-sized) AND short. Width alone can't distinguish it from a narrow iPad Slide
    /// Over/multitasking window, which is also under 500pt wide; the floating keyboard's own window
    /// is small in both dimensions (~320x225), while a Slide Over pane keeps the host app's full
    /// device height even though it's narrow. Pure — no UIKit trait collection/window access — so
    /// it's unit-testable without a live view hierarchy.
    static func isFloatingKeyboard(isPad: Bool, width: CGFloat, containerHeight: CGFloat) -> Bool {
        guard isPad, width < 500 else { return false }
        return containerHeight < 500
    }

    /// The container height fed into `clampedHeight`'s `maxHeightCap` (50% of container). Prefers
    /// the real window height — only trustworthy once the extension's view is actually attached to
    /// its host window. When the window isn't attached yet (`windowHeight == nil`), falls straight
    /// to the physical screen height rather than `inputView.superview.bounds.height`: that
    /// superview is the system's own placeholder input-view container, sized to a small
    /// default/system keyboard height (not the real available height) until our own constraint
    /// takes over. Some hosts — the Notification Center quick-reply compose field chief among them
    /// — run `viewWillAppear` with `window == nil`, so trusting that placeholder there collapsed
    /// `maxHeightCap` below `minHeight` and silently pinned every preset to the 220pt floor. Pure —
    /// no UIKit window/view access — so it's unit-testable without a live view hierarchy.
    static func clampCeilingContainerHeight(windowHeight: CGFloat?, screenHeight: CGFloat) -> CGFloat {
        return windowHeight ?? screenHeight
    }
}

/// Bottom-row switch-key glyph identifiers. Shared (app + Keyboard targets) so the "distinct from
/// the system globe" invariant is unit-testable from the app target even though the keys
/// themselves (`Item`, `Cell`) are compiled only into the Keyboard extension.
///
/// The pack-switch key (cycles keyboard packs / long-press opens the pack picker) used to render
/// via a bundled asset that was, visually, a second globe — indistinguishable from the real
/// system keyboard-switch key. `packSwitchImageName` has no bundled asset, so `Cell.configure`
/// falls back to the SF Symbol of the same name (see `Cell.swift`), giving the pack key its own
/// identity everywhere while the true globe key keeps rendering the system "globe" glyph.
enum KeyGlyph {
    static let packSwitch = "square.grid.2x2"
}

enum KeyboardType: String {
    case `default`, math, math2, finance, symbols, programmer, tax, custom
    // 2.0 packs (Phase 2). `programmerPlus` is the extended programmer pack; the rest are new domains.
    // `datetime` and `international` are computed packs wired in later sub-phases.
    // `units` was revived as a real à la carte pack (pack-lineup pass) — see `ProductCatalog` and
    // `KeyboardType.packs` below; `scientific`, `business`, `international`, `programmerPlus` remain
    // decode-only (never selectable, never sold).
    case units, scientific, datetime, business, international, programmerPlus
    // `cooking` is a brand-new pack (pack-lineup pass, stream 2) — no legacy decode-only baggage,
    // unlike the five above.
    case cooking
    // NumPad Type's QWERTY-side Grammar pack (docs/plans/full-keyboard/ §2). Never in `packs`
    // (not selectable on the numpad, not sold — see `ProductCatalog`); it lives on the QWERTY
    // top strip via `QwertyPackFamily`.
    case grammar

    // NOTE: `.tax` is intentionally not a selectable pack — its old pack row was removed (keys had
    // no handler and inserted literal text). Tax/Tip lives in the long-press "%" overlay instead.
    // The case remains so a stale persisted `.tax` selection still decodes (falls back to no pack row).
    static var packs: [KeyboardType] {
        return [.math, .math2, .finance, .symbols, .programmer, .datetime, .units, .cooking]
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
        case .cooking:
            return NSLocalizedString("Cooking & Baking", comment: "Keyboard type name for the cooking and baking pack")
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
        case .grammar:
            return NSLocalizedString("Grammar", comment: "Keyboard type name for the QWERTY-side grammar pack")
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
    // iOS 26 Liquid Glass premium pair. Light/dark twin so automatic-dark-mode users get a glass
    // look in both appearances. See `isGlass` / `UIColor.itemScheme` for the real-material vs.
    // translucent-gray-fallback split.
    case glass, glassDark

    var name: String {
        switch self {
        case .deepPurple: return NSLocalizedString("Deep Purple", comment: "")
        case .lightBlue: return NSLocalizedString("Light Blue", comment: "")
        case .lightGreen: return NSLocalizedString("Light Green", comment: "")
        case .deepOrange: return NSLocalizedString("Deep Orange", comment: "")
        case .glass: return NSLocalizedString("Glass", comment: "")
        case .glassDark: return NSLocalizedString("Glass Dark", comment: "")
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
        case .glass: return Color.glass
        case .glassDark: return Color.glassDark
        }
    }

    /// Either half of the Liquid Glass pair. Drives the real-material path on iOS 26
    /// (`KeyboardViewController.applyGlassBackdrop`) and the translucent-gray fallback everywhere
    /// else (both derive from `color` already carrying reduced alpha — see `Color.glass`).
    var isGlass: Bool {
        self == .glass || self == .glassDark
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
