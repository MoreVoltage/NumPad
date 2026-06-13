//
//  SharedExtensions.swift
//  NumPad
//
//  Created by Lasha Efremidze on 3/9/17.
//  Copyright © 2017 MoreVoltage. All rights reserved.
//

import UIKit
import CoreFoundation
import Security

extension UserDefaults {
    static let group = UserDefaults(suiteName: "group.morevoltage.numpad.container")!
}

@propertyWrapper
struct UserDefault<T> {
    let key: String
    let defaultValue: T
    let userDefaults: UserDefaults
    
    var wrappedValue: T {
        get { return userDefaults.object(forKey: key) as? T ?? defaultValue }
        set { userDefaults.set(newValue, forKey: key) }
    }
}

extension UIButton {
    
    var title: String? {
        get { return title(for: .normal) }
        set { setTitle(newValue, for: .normal) }
    }
    
    var titleColor: UIColor? {
        get { return titleColor(for: .normal) }
        set { setTitleColor(newValue, for: .normal) }
    }
    
    var image: UIImage? {
        get { return image(for: .normal) }
        set { setImage(newValue, for: .normal) }
    }
    
}

typealias Color = UIColor.Custom

extension UIColor {
    
    convenience init(red: Int, green: Int, blue: Int) {
        self.init(red: CGFloat(red) / 255, green: CGFloat(green) / 255, blue: CGFloat(blue) / 255, alpha: 1)
    }
    
    struct Custom {
        static var red: UIColor { return UIColor(red: 244, green: 67, blue: 54) }
        static var pink: UIColor { return UIColor(red: 233, green: 30, blue: 99) }
        static var purple: UIColor { return UIColor(red: 156, green: 39, blue: 176) }
        static var deepPurple: UIColor { return UIColor(red: 103, green: 58, blue: 183) }
        static var indigo: UIColor { return UIColor(red: 63, green: 81, blue: 181) }
        static var blue: UIColor { return UIColor(red: 33, green: 150, blue: 243) }
        static var lightBlue: UIColor { return UIColor(red: 3, green: 169, blue: 244) }
        static var teal: UIColor { return UIColor(red: 0, green: 150, blue: 136) }
        static var green: UIColor { return UIColor(red: 76, green: 175, blue: 80) }
        static var lightGreen: UIColor { return UIColor(red: 139, green: 195, blue: 74) }
        static var lime: UIColor { return UIColor(red: 205, green: 220, blue: 57) }
        static var yellow: UIColor { return UIColor(red: 255, green: 235, blue: 59) }
        static var amber: UIColor { return UIColor(red: 255, green: 193, blue: 7) }
        static var orange: UIColor { return UIColor(red: 255, green: 152, blue: 0) }
        static var deepOrange: UIColor { return UIColor(red: 255, green: 87, blue: 34) }
    }
    
    class var primary: UIColor {
        return systemBlue
    }
    
    class var text: UIColor {
        return label
    }
    
    func image(_ size: CGSize = CGSize(width: 1, height: 1)) -> UIImage {
        return UIGraphicsImageRenderer(size: size).image { context in
            self.setFill()
            context.fill(.init(origin: .zero, size: size))
        }
    }
    
}

struct Theme {
    static var isDarkMode: Bool {
        return UITraitCollection.current.userInterfaceStyle == .dark
    }
}

enum Constants: String {
    case reversedMode, roundedCorners, grid, selectedKeyboardType, selectedKeyboardTheme, automaticDarkMode, paywallEnabled, snippets, hapticsEnabled, soundEnabled, rcApplied
    // Behavior toggles (were previously inline string literals)
    case repurposeNextKey, clipboardHistory, clipboardHistoryEnabled
    // StoreKit 2 purchases (written only by the app; the keyboard extension reads them)
    case proPurchased, financePackPurchased, grandfathered, grandfatherChecked
    // v2 re-runs the grandfather check with the AppTransaction.environment guard, clearing
    // bogus sandbox-derived grandfathering cached under the v1 key (App Review / TestFlight
    // installs where originalAppVersion is always "1.0").
    case grandfatherCheckedV2
    // Development-only entitlement simulation toggles (used by the DEBUG Store section only)
    case debugProOverride, debugForceLocked
    // Customizable keys: the three remappable right-side slots and the user-built Custom pack
    case customKeySlots, customPackKeys
    // Experimental feature flags — all OFF by default, surfaced for toggling only in
    // DEBUG/TestFlight builds (see FeatureFlags). Stored in the app group so the keyboard
    // extension reads the same value the app writes.
    case ffInlineCalculator, ffLocaleSeparators, ffCursorControls, ffConversionOverlay
    case ffLastResultTape, ffSaveSnippetFromKeyboard, ffICloudSync, ffSmartPackDefaulting
    // Data backing for experimental features
    case resultTape
}

// MARK: - Cross-process settings sync (App ↔︎ Keyboard Extension)

/// Holds the handler and a *weak* reference to the registering object. The Darwin callback
/// only receives the raw observer pointer; keeping a weak ref lets us ignore callbacks that
/// arrive after the observer was deallocated (e.g. if `remove()` was missed, or the OS reused
/// the same address for a new object), instead of dispatching to a stale/wrong instance.
private final class NPHandlerBox {
    weak var observer: AnyObject?
    let handler: () -> Void
    init(observer: AnyObject, handler: @escaping () -> Void) {
        self.observer = observer
        self.handler = handler
    }
}

private var settingsSyncHandlers: [UnsafeMutableRawPointer: NPHandlerBox] = [:]

enum SettingsSync {
    private static let notificationName = "com.morevoltage.numpad.settingsChanged"

    static func post() {
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFNotificationName(notificationName as CFString), nil, nil, true)
    }

    static func observe(_ observer: AnyObject, handler: @escaping () -> Void) {
        // Clear any stale registration at this address before re-adding.
        remove(observer)
        let key = Unmanaged.passUnretained(observer).toOpaque()
        settingsSyncHandlers[key] = NPHandlerBox(observer: observer, handler: handler)
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), key, settingsChangedCFCallback, notificationName as CFString, nil, .deliverImmediately)
    }

    static func remove(_ observer: AnyObject) {
        let key = Unmanaged.passUnretained(observer).toOpaque()
        settingsSyncHandlers.removeValue(forKey: key)
        CFNotificationCenterRemoveObserver(CFNotificationCenterGetDarwinNotifyCenter(), key, CFNotificationName(notificationName as CFString), nil)
    }
}

// C-compatible callback for Darwin notifications (must not capture Swift context)
private func settingsChangedCFCallback(_ center: CFNotificationCenter?, _ observer: UnsafeMutableRawPointer?, _ name: CFNotificationName?, _ object: UnsafeRawPointer?, _ userInfo: CFDictionary?) {
    guard let observer = observer, let box = settingsSyncHandlers[observer], box.observer != nil else { return }
    DispatchQueue.main.async { box.handler() }
}

#if canImport(FirebaseCore)
import FirebaseCore
import FirebaseAnalytics
#if canImport(FirebaseCrashlytics)
import FirebaseCrashlytics
#endif

struct Analytics {
    static let start: Void = {
        FirebaseApp.configure()
    }()
    static func logEvent(name: String, attributes: [String: Any] = [:]) {
        let attributes = attributes.mapValues {
            $0 is Bool ? "\($0)" : $0
        }
        FirebaseAnalytics.Analytics.logEvent(name, parameters: attributes)
    }
    static let ParameterValue = FirebaseAnalytics.AnalyticsParameterValue
}
#else
// Keyboard extension: Firebase is intentionally not linked. The extension never logs events
// (no keystroke tracking), and statically linked Firebase added hundreds of ObjC classes to
// register at dyld time — a measurable keyboard cold-start cost. This no-op stub keeps
// SharedExtensions compiling in both targets.
struct Analytics {
    static let start: Void = ()
    static func logEvent(name: String, attributes: [String: Any] = [:]) {}
    static let ParameterValue = "value"
}
#endif

// MARK: - Monetization Feature Flags

struct Monetization {
    /// Master switch. ON by default in 1.7.0 — real purchases gate premium content.
    @UserDefault(key: Constants.paywallEnabled.rawValue, defaultValue: true, userDefaults: .group)
    static var paywallEnabled: Bool

    // MARK: Stored purchase state (written by StoreManager in the app; read-only in the extension)

    /// True when the "numpad.pro.lifetime" non-consumable is owned.
    @UserDefault(key: Constants.proPurchased.rawValue, defaultValue: false, userDefaults: .group)
    static var isProPurchased: Bool

    /// True when the "numpad.pack.finance" non-consumable is owned.
    @UserDefault(key: Constants.financePackPurchased.rawValue, defaultValue: false, userDefaults: .group)
    static var isFinancePackPurchased: Bool

    /// True for users whose original purchase predates 1.7.0 — they keep everything free.
    @UserDefault(key: Constants.grandfathered.rawValue, defaultValue: false, userDefaults: .group)
    static var isGrandfathered: Bool

    #if DEBUG
    /// Development-only entitlement simulation (Store screen DEBUG section). Never ships.
    @UserDefault(key: Constants.debugProOverride.rawValue, defaultValue: false, userDefaults: .group)
    static var debugProOverride: Bool

    /// Development-only: force the locked state even when this install is grandfathered or has
    /// purchases, so lock chips can always be exercised. (Note: since the v2 grandfather check,
    /// sandbox/TestFlight installs are never grandfathered — only real sandbox purchases unlock.)
    /// Takes precedence over everything.
    @UserDefault(key: Constants.debugForceLocked.rawValue, defaultValue: false, userDefaults: .group)
    static var debugForceLocked: Bool
    #endif

    /// Computed entitlement: a real purchase or a grandfathered install unlocks everything.
    static var isProEntitled: Bool {
        #if DEBUG
        if debugForceLocked { return false }
        if debugProOverride { return true }
        #endif
        return isProPurchased || isGrandfathered
    }

    // MARK: Gating map
    //
    // Free always:   default pack, math, math2, non-premium themes
    // Pro unlocks:   finance, symbols, programmer, tax packs + KeyboardTheme.premiumThemes
    // Finance Pack:  unlocks the finance pack only

    /// Whether a given keyboard pack is locked for the current user.
    static func isLocked(pack: KeyboardType) -> Bool {
        guard paywallEnabled, !isProEntitled else { return false }
        switch pack {
        case .default, .math, .math2:
            return false
        case .finance:
            #if DEBUG
            if debugForceLocked { return true }
            #endif
            return !isFinancePackPurchased
        case .symbols, .programmer, .tax, .custom:
            return true
        }
    }

    /// Whether a given theme is locked for the current user.
    static func isLocked(theme: KeyboardTheme) -> Bool {
        guard paywallEnabled, !isProEntitled else { return false }
        return theme.isPremium
    }

    /// Single source of truth for whether an individual key renders/behaves as locked. A key is
    /// locked when it sits in the extra pack row (row 0 of a non-default pack) of a locked pack —
    /// e.g. the selected pack became locked after a paywall/entitlement change. Used by both the
    /// lock-chip overlay (StackView) and the tap handler (KeyboardViewController) so the visual
    /// locked state and the actual behavior can never drift apart.
    static func isKeyLocked(pack: KeyboardType, row: Int) -> Bool {
        guard row == 0, pack != .default else { return false }
        return isLocked(pack: pack)
    }
}

// MARK: - User Preferences (Haptics / Sound)

struct UserPrefs {
    @UserDefault(key: Constants.hapticsEnabled.rawValue, defaultValue: true, userDefaults: .group)
    static var hapticsEnabled: Bool
    @UserDefault(key: Constants.soundEnabled.rawValue, defaultValue: true, userDefaults: .group)
    static var soundEnabled: Bool
    @UserDefault(key: Constants.repurposeNextKey.rawValue, defaultValue: true, userDefaults: .group)
    static var repurposeNextKey: Bool

    // When disabled, the keyboard neither captures nor displays clipboard history.
    @UserDefault(key: Constants.clipboardHistoryEnabled.rawValue, defaultValue: true, userDefaults: .group)
    static var clipboardHistoryEnabled: Bool
}

// MARK: - Experimental Feature Flags
//
// Every new (post-1.7.0) capability is gated behind one of these flags and ships **OFF by
// default**, so production behavior is unchanged until a flag is explicitly enabled. The toggles
// are only *surfaced* in DEBUG and TestFlight builds (`experimentalUIVisible`); App Store users
// never see them. Flags live in the shared app group so the keyboard extension reads the same
// value the container app writes (followed by `SettingsSync.post()` so a live keyboard reacts).
struct FeatureFlags {
    @UserDefault(key: Constants.ffInlineCalculator.rawValue, defaultValue: false, userDefaults: .group)
    static var inlineCalculator: Bool

    @UserDefault(key: Constants.ffLocaleSeparators.rawValue, defaultValue: false, userDefaults: .group)
    static var localeAwareSeparators: Bool

    @UserDefault(key: Constants.ffCursorControls.rawValue, defaultValue: false, userDefaults: .group)
    static var cursorControls: Bool

    @UserDefault(key: Constants.ffConversionOverlay.rawValue, defaultValue: false, userDefaults: .group)
    static var conversionOverlay: Bool

    @UserDefault(key: Constants.ffLastResultTape.rawValue, defaultValue: false, userDefaults: .group)
    static var lastResultTape: Bool

    @UserDefault(key: Constants.ffSaveSnippetFromKeyboard.rawValue, defaultValue: false, userDefaults: .group)
    static var saveSnippetFromKeyboard: Bool

    @UserDefault(key: Constants.ffICloudSync.rawValue, defaultValue: false, userDefaults: .group)
    static var iCloudSync: Bool

    @UserDefault(key: Constants.ffSmartPackDefaulting.rawValue, defaultValue: false, userDefaults: .group)
    static var smartPackDefaulting: Bool

    /// One row per flag, for building the settings UI generically.
    struct Flag {
        let title: String
        let subtitle: String
        let get: () -> Bool
        let set: (Bool) -> Void
    }

    /// All experimental flags, in display order. The setter posts `SettingsSync` so a running
    /// keyboard extension picks the change up immediately.
    static var all: [Flag] {
        [
            Flag(title: NSLocalizedString("Inline Calculator", comment: "Feature flag"),
                 subtitle: NSLocalizedString("Evaluate expressions when you tap =", comment: "Feature flag detail"),
                 get: { inlineCalculator }, set: { inlineCalculator = $0; SettingsSync.post() }),
            Flag(title: NSLocalizedString("Locale-Aware Separators", comment: "Feature flag"),
                 subtitle: NSLocalizedString("Use your region's decimal separator", comment: "Feature flag detail"),
                 get: { localeAwareSeparators }, set: { localeAwareSeparators = $0; SettingsSync.post() }),
            Flag(title: NSLocalizedString("Cursor Controls", comment: "Feature flag"),
                 subtitle: NSLocalizedString("Move the caret from the keyboard", comment: "Feature flag detail"),
                 get: { cursorControls }, set: { cursorControls = $0; SettingsSync.post() }),
            Flag(title: NSLocalizedString("Conversion Overlay", comment: "Feature flag"),
                 subtitle: NSLocalizedString("Quick unit & currency conversions", comment: "Feature flag detail"),
                 get: { conversionOverlay }, set: { conversionOverlay = $0; SettingsSync.post() }),
            Flag(title: NSLocalizedString("Last-Result Tape", comment: "Feature flag"),
                 subtitle: NSLocalizedString("Keep recent calculator results", comment: "Feature flag detail"),
                 get: { lastResultTape }, set: { lastResultTape = $0; SettingsSync.post() }),
            Flag(title: NSLocalizedString("Save Snippet From Keyboard", comment: "Feature flag"),
                 subtitle: NSLocalizedString("Save the last result as a snippet", comment: "Feature flag detail"),
                 get: { saveSnippetFromKeyboard }, set: { saveSnippetFromKeyboard = $0; SettingsSync.post() }),
            Flag(title: NSLocalizedString("iCloud Sync", comment: "Feature flag"),
                 subtitle: NSLocalizedString("Sync snippets across your devices", comment: "Feature flag detail"),
                 get: { iCloudSync }, set: { iCloudSync = $0; SettingsSync.post() }),
            Flag(title: NSLocalizedString("Smart Pack Defaulting", comment: "Feature flag"),
                 subtitle: NSLocalizedString("Auto-pick a pack to match the field", comment: "Feature flag detail"),
                 get: { smartPackDefaulting }, set: { smartPackDefaulting = $0; SettingsSync.post() }),
        ]
    }

    /// Whether the experimental flags UI should be shown. DEBUG builds always show it; release
    /// builds show it only under TestFlight (sandbox receipt), never on the App Store. Evaluated
    /// in the app target — the keyboard extension only ever *reads* the flags, not this gate.
    static var experimentalUIVisible: Bool {
        #if DEBUG
        return true
        #else
        return Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
        #endif
    }
}

// MARK: - Tax/Tip math (pure, unit-tested)

/// Pure math for the Tax/Tip overlay. Tip is computed on the pre-tax subtotal (the standard
/// convention on receipts), so total = amount × (1 + tax + tip).
enum TaxTipMath {
    /// The full amount including tax and tip.
    static func total(amount: Double, taxRate: Double, tipRate: Double) -> Double {
        return amount * (1 + taxRate + tipRate)
    }

    /// Just the tip, computed on the pre-tax amount.
    static func tipOnly(amount: Double, tipRate: Double) -> Double {
        return amount * tipRate
    }
}

// MARK: - Calculator (inline expression evaluation)

/// A small, dependency-free arithmetic evaluator for the inline-calculator feature. Deliberately
/// **not** built on `NSExpression` (which can resolve `FUNCTION(...)` calls and other surprises) —
/// it only understands `+ - * / × ÷ %`, parentheses, unary minus, and decimal numbers, and is pure
/// so it can be unit-tested without any UIKit/StoreKit context.
enum Calculator {

    /// Evaluate an arithmetic expression. `decimalSeparator` lets locale-formatted input (e.g.
    /// "1,5") parse correctly. Returns `nil` for empty, malformed, or non-finite results (incl.
    /// division by zero) so callers can fall back gracefully.
    static func evaluate(_ expression: String, decimalSeparator: String = ".") -> Double? {
        var normalized = expression
            .replacingOccurrences(of: "×", with: "*")
            .replacingOccurrences(of: "÷", with: "/")
            .replacingOccurrences(of: "−", with: "-")
        if decimalSeparator != "." {
            // Group separators would be ambiguous, so locale mode only remaps the decimal mark.
            normalized = normalized.replacingOccurrences(of: decimalSeparator, with: ".")
        }
        guard let tokens = tokenize(normalized) else { return nil }
        guard let rpn = toRPN(tokens) else { return nil }
        guard let value = evalRPN(rpn), value.isFinite else { return nil }
        return value
    }

    /// Format a result for insertion: integers render without a trailing ".0", and the decimal mark
    /// honors `decimalSeparator`. Rounded to at most 10 significant fractional digits.
    static func format(_ value: Double, decimalSeparator: String = ".") -> String {
        var text: String
        if value.rounded() == value, abs(value) < 1e15 {
            text = String(Int(value))
        } else {
            text = String(format: "%g", value)
        }
        if decimalSeparator != "." {
            text = text.replacingOccurrences(of: ".", with: decimalSeparator)
        }
        return text
    }

    // MARK: Tokenizer / shunting-yard

    private enum Token: Equatable {
        case number(Double)
        case op(Character)
        case lparen, rparen
    }

    private static func tokenize(_ s: String) -> [Token]? {
        var tokens: [Token] = []
        let chars = Array(s)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if c.isWhitespace { i += 1; continue }
            if c.isNumber || c == "." {
                var num = ""
                while i < chars.count, chars[i].isNumber || chars[i] == "." {
                    num.append(chars[i]); i += 1
                }
                guard let d = Double(num) else { return nil }
                tokens.append(.number(d))
                continue
            }
            switch c {
            case "+", "-", "*", "/", "%":
                tokens.append(.op(c))
            case "(":
                tokens.append(.lparen)
            case ")":
                tokens.append(.rparen)
            default:
                return nil // unknown character → not a valid expression
            }
            i += 1
        }
        return tokens.isEmpty ? nil : tokens
    }

    /// `~` is the internal unary-negation operator, with higher precedence than * and / so it binds
    /// tightest (e.g. 3 * -2 = -6, not (3*0)-2). It can never come from tokenize().
    private static func precedence(_ op: Character) -> Int {
        switch op {
        case "+", "-": return 1
        case "*", "/", "%": return 2
        case "~": return 3
        default: return 0
        }
    }

    private static func isOp(_ token: Token?) -> Bool {
        if case .op = token { return true }
        return false
    }

    private static func toRPN(_ tokens: [Token]) -> [Token]? {
        var output: [Token] = []
        var stack: [Token] = []
        var prev: Token?
        for token in tokens {
            switch token {
            case .number:
                output.append(token)
            case .op(let o):
                // A leading sign, or a sign right after another operator or "(", is unary.
                let isUnary = (o == "-" || o == "+") && (prev == nil || prev == .lparen || isOp(prev))
                if isUnary {
                    // Unary plus is a no-op; unary minus pushes the high-precedence "~" negation.
                    if o == "-" { stack.append(.op("~")) }
                } else {
                    while let top = stack.last, case .op(let t) = top, precedence(t) >= precedence(o) {
                        output.append(stack.removeLast())
                    }
                    stack.append(token)
                }
            case .lparen:
                stack.append(token)
            case .rparen:
                var matched = false
                while let top = stack.last {
                    if top == .lparen { stack.removeLast(); matched = true; break }
                    output.append(stack.removeLast())
                }
                if !matched { return nil } // unbalanced parentheses
            }
            prev = token
        }
        while let top = stack.popLast() {
            if top == .lparen { return nil }
            output.append(top)
        }
        return output
    }

    private static func evalRPN(_ rpn: [Token]) -> Double? {
        var stack: [Double] = []
        for token in rpn {
            switch token {
            case .number(let d):
                stack.append(d)
            case .op(let o):
                if o == "~" {
                    guard let a = stack.popLast() else { return nil }
                    stack.append(-a)
                    break
                }
                guard stack.count >= 2 else { return nil }
                let b = stack.removeLast(); let a = stack.removeLast()
                switch o {
                case "+": stack.append(a + b)
                case "-": stack.append(a - b)
                case "*": stack.append(a * b)
                case "/": guard b != 0 else { return nil }; stack.append(a / b)
                case "%": guard b != 0 else { return nil }; stack.append(a.truncatingRemainder(dividingBy: b))
                default: return nil
                }
            default:
                return nil
            }
        }
        return stack.count == 1 ? stack.first : nil
    }
}

// MARK: - Unit Converter (offline conversions)

/// Pure, offline unit conversion for the conversion-overlay feature. Length and mass go through a
/// linear base-unit factor; temperature is handled specially (affine, not linear). No network — so
/// currency is intentionally out of scope (it needs live rates a keyboard extension can't fetch).
enum UnitConverter {

    enum Category: String, CaseIterable {
        case length, mass, temperature
        var displayName: String {
            switch self {
            case .length: return NSLocalizedString("Length", comment: "Conversion category")
            case .mass: return NSLocalizedString("Mass", comment: "Conversion category")
            case .temperature: return NSLocalizedString("Temperature", comment: "Conversion category")
            }
        }
        /// Units in this category, in display order. The first two are the default from/to pair.
        var units: [String] {
            switch self {
            case .length: return ["cm", "in", "m", "ft", "km", "mi"]
            case .mass: return ["kg", "lb", "g", "oz"]
            case .temperature: return ["°C", "°F"]
            }
        }
    }

    /// Each linear unit's category and factor to its category's base unit (meters / kilograms).
    /// Tagging the category lets `convert` reject cross-category requests (e.g. metres → kilograms).
    private static let unitInfo: [String: (category: Category, factor: Double)] = [
        // length → meters
        "cm": (.length, 0.01), "in": (.length, 0.0254), "m": (.length, 1),
        "ft": (.length, 0.3048), "km": (.length, 1000), "mi": (.length, 1609.344),
        // mass → kilograms
        "kg": (.mass, 1), "lb": (.mass, 0.45359237), "g": (.mass, 0.001), "oz": (.mass, 0.028349523125)
    ]

    /// Convert `value` from one unit to another. Returns nil if the units are unknown or belong to
    /// different categories (e.g. length → mass).
    static func convert(_ value: Double, from: String, to: String) -> Double? {
        if from == to { return value }
        // Temperature is affine, handled explicitly.
        if from == "°C" && to == "°F" { return value * 9 / 5 + 32 }
        if from == "°F" && to == "°C" { return (value - 32) * 5 / 9 }
        guard let f = unitInfo[from], let t = unitInfo[to], f.category == t.category else { return nil }
        return value * f.factor / t.factor
    }
}

// MARK: - Result Tape (recent calculator results)

/// Stores recent inline-calculator results so they can be re-inserted (last-result-tape feature).
/// Results are not sensitive (plain numbers), so the shared `UserDefaults` group is sufficient.
final class ResultTape {
    static let shared = ResultTape()
    private let userDefaults = UserDefaults.group
    private let key = Constants.resultTape.rawValue
    private let maxItems = 20
    private let lock = NSLock()

    private init() {}

    /// Most-recent-first list of recent results.
    var results: [String] {
        get { userDefaults.stringArray(forKey: key) ?? [] }
        set { userDefaults.set(Array(newValue.prefix(maxItems)), forKey: key) }
    }

    func add(_ result: String) {
        guard !result.isEmpty else { return }
        lock.lock(); defer { lock.unlock() }
        var items = results.filter { $0 != result }
        items.insert(result, at: 0)
        results = items
    }

    func clear() {
        lock.lock(); defer { lock.unlock() }
        userDefaults.removeObject(forKey: key)
    }
}

// MARK: - Snippets Manager

struct Snippet: Codable, Equatable {
    var title: String
    var text: String
}

class SnippetsManager {
    static let shared = SnippetsManager()
    private let userDefaults = UserDefaults.group
    private let key = Constants.snippets.rawValue
    private let maxItems = 100
    // Serializes read-modify-write so concurrent add/remove on the same process can't lose updates.
    private let lock = NSLock()
    // iCloud key-value store mirror, used only when FeatureFlags.iCloudSync is on. NOTE: this only
    // actually syncs if the app has the iCloud "Key-Value storage" capability/entitlement; without
    // it the calls are harmless no-ops. The flag is off by default.
    private let cloud = NSUbiquitousKeyValueStore.default

    private init() {}

    var snippets: [Snippet] {
        get {
            guard let data = userDefaults.data(forKey: key) else { return [] }
            return (try? JSONDecoder().decode([Snippet].self, from: data)) ?? []
        }
        set {
            let capped = Array(newValue.prefix(maxItems))
            writeLocal(capped)
            pushToCloudIfEnabled(capped)
        }
    }

    private func writeLocal(_ items: [Snippet]) {
        let data = try? JSONEncoder().encode(items)
        userDefaults.set(data, forKey: key)
    }

    private func pushToCloudIfEnabled(_ items: [Snippet]) {
        guard FeatureFlags.iCloudSync, let data = try? JSONEncoder().encode(items) else { return }
        cloud.set(data, forKey: key)
        cloud.synchronize()
    }

    /// Pull snippets from iCloud into the local store (last-write-wins). No-op when the flag is off
    /// or there's nothing in the cloud. Writes locally without re-pushing to avoid a sync loop.
    func pullFromCloudIfEnabled() {
        guard FeatureFlags.iCloudSync,
              let data = cloud.data(forKey: key),
              let items = try? JSONDecoder().decode([Snippet].self, from: data) else { return }
        lock.lock(); defer { lock.unlock() }
        writeLocal(items)
    }

    func add(_ snippet: Snippet) {
        lock.lock(); defer { lock.unlock() }
        var items = snippets
        // De-duplicate by title
        items.removeAll { $0.title == snippet.title }
        items.insert(snippet, at: 0)
        snippets = items
    }

    func remove(at index: Int) {
        lock.lock(); defer { lock.unlock() }
        var items = snippets
        guard items.indices.contains(index) else { return }
        items.remove(at: index)
        snippets = items
    }
}

// MARK: - Custom Right-Side Keys (remappable bottom-row slots)

/// The three remappable key slots on the right side of the keyboard (defaults: comma, period,
/// space). Each slot stores a raw token: a literal string to insert, or one of the special
/// tokens below for keys whose inserted text differs from their label. Enter and backspace are
/// intentionally not remappable — enter carries per-app return-key semantics, and a keyboard
/// without backspace is unusable.
struct CustomKeys {
    /// Inserts " " — can't be represented literally because the key label must read "Space".
    static let spaceToken = "{space}"
    /// Inserts "\t" — moves to the next cell in spreadsheet apps.
    static let tabToken = "{tab}"
    /// Moves the cursor one character left/right instead of inserting text.
    static let cursorLeftToken = "{left}"
    static let cursorRightToken = "{right}"
    /// Dismisses the keyboard instead of inserting text.
    static let dismissToken = "{dismiss}"

    static let slotCount = 3
    static let maxTokenLength = 4
    static let defaultSlots = [",", ".", spaceToken]

    /// Tokens offered by the app's key palette (plus free-form input).
    static let palette = [",", ".", spaceToken, tabToken, "-", "+", "=", "%", "$", ":", ";", "/", "(", ")", "#", "00", "000", cursorLeftToken, cursorRightToken, dismissToken]

    @UserDefault(key: Constants.customKeySlots.rawValue, defaultValue: CustomKeys.defaultSlots, userDefaults: .group)
    private static var _slots: [String]

    /// Always exactly `slotCount` tokens — pads missing entries with the defaults and ignores extras.
    static var slots: [String] {
        get {
            var values = _slots.map { $0.isEmpty ? defaultSlots[0] : $0 }
            if values.count < slotCount {
                values += defaultSlots[values.count...]
            }
            return Array(values.prefix(slotCount))
        }
        set {
            _slots = Array(newValue.prefix(slotCount))
        }
    }

    /// Human-readable name for a token — used for both the key label and the app's settings UI.
    static func displayName(for token: String) -> String {
        switch token {
        case spaceToken: return NSLocalizedString("Space", comment: "")
        case tabToken: return NSLocalizedString("Tab", comment: "Name of the tab key")
        case cursorLeftToken: return "←"
        case cursorRightToken: return "→"
        case dismissToken: return NSLocalizedString("Hide", comment: "Label for the key that dismisses the keyboard")
        default: return token
        }
    }

    /// The text a token inserts into the host app. Action tokens (cursor movement, dismiss)
    /// insert nothing — the keyboard performs their action instead (see KeyboardViewController).
    static func insertedText(for token: String) -> String {
        switch token {
        case spaceToken: return " "
        case tabToken: return "\t"
        case cursorLeftToken, cursorRightToken, dismissToken: return ""
        default: return token
        }
    }
}

// MARK: - Custom Pack Manager

/// User-defined keys for the Custom keyboard pack. Keys are short strings inserted verbatim;
/// longer text belongs in Snippets.
class CustomPackManager {
    static let shared = CustomPackManager()
    static let maxKeys = 10
    static let maxKeyLength = 4

    private let userDefaults = UserDefaults.group
    private let key = Constants.customPackKeys.rawValue
    // Serializes read-modify-write so concurrent add/remove on the same process can't lose updates.
    private let lock = NSLock()

    private init() {}

    var keys: [String] {
        get {
            return userDefaults.stringArray(forKey: key) ?? []
        }
        set {
            let sanitized = newValue
                .map { String($0.prefix(Self.maxKeyLength)) }
                .filter { !$0.isEmpty }
            userDefaults.set(Array(sanitized.prefix(Self.maxKeys)), forKey: key)
        }
    }

    func add(_ text: String) {
        lock.lock(); defer { lock.unlock() }
        let trimmed = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.maxKeyLength))
        guard !trimmed.isEmpty else { return }
        var items = keys
        // De-duplicate; re-adding an existing key moves it to the end
        items.removeAll { $0 == trimmed }
        items.append(trimmed)
        keys = items
    }

    func remove(at index: Int) {
        lock.lock(); defer { lock.unlock() }
        var items = keys
        guard items.indices.contains(index) else { return }
        items.remove(at: index)
        keys = items
    }

    func move(from sourceIndex: Int, to destinationIndex: Int) {
        lock.lock(); defer { lock.unlock() }
        var items = keys
        guard items.indices.contains(sourceIndex), items.indices.contains(destinationIndex) else { return }
        let item = items.remove(at: sourceIndex)
        items.insert(item, at: destinationIndex)
        keys = items
    }
}

// Premium labeling helpers
extension KeyboardTheme {
    static var premiumThemes: [KeyboardTheme] {
        return [.black, .deepPurple, .indigo, .teal, .deepOrange]
    }
    var isPremium: Bool { KeyboardTheme.premiumThemes.contains(self) }
}

// MARK: - Firebase Remote Config
#if canImport(FirebaseRemoteConfig)
import FirebaseRemoteConfig

struct RemoteConfigManager {
    static let shared = RemoteConfigManager()
    private let rc = RemoteConfig.remoteConfig()

    static func start() {
        _ = Analytics.start
        RemoteConfigManager.shared.configureDefaults()
        RemoteConfigManager.shared.fetchAndActivate()
    }

    func configureDefaults() {
        let defaults: [String: NSObject] = [
            "price_copy": "Unlock Pro to access premium themes and packs" as NSObject,
            "default_theme": KeyboardTheme.white.rawValue as NSObject,
            "default_pack": KeyboardType.default.rawValue as NSObject,
            "packs_enabled": "math,math2,finance,symbols,programmer,custom" as NSObject,
            "tax_default_percent": 15 as NSNumber
        ]
        rc.setDefaults(defaults)
    }

    func fetchAndActivate() {
        rc.fetchAndActivate(completionHandler: { _, _ in })
    }

    var priceCopy: String { rc["price_copy"].stringValue }
    var defaultTheme: KeyboardTheme { KeyboardTheme(rawValue: rc["default_theme"].stringValue) ?? .white }
    var defaultPack: KeyboardType { KeyboardType(rawValue: rc["default_pack"].stringValue) ?? .default }
    var enabledPacks: [KeyboardType] {
        let csv = rc["packs_enabled"].stringValue
        let names = Set(csv.split(separator: ",").map { String($0) })
        return KeyboardType.packs.filter { names.contains($0.rawValue) }
    }
    var taxDefaultPercent: Int {
        let v = Int(truncating: rc["tax_default_percent"].numberValue)
        return [5,10,15,18,20,25].contains(v) ? v : 15
    }
}
#else
// Fallback stub for targets without Remote Config (e.g., the Keyboard extension)
struct RemoteConfigManager {
    static let shared = RemoteConfigManager()
    static func start() { _ = Analytics.start }
    func configureDefaults() {}
    func fetchAndActivate() {}
    var priceCopy: String { "" }
    var defaultTheme: KeyboardTheme { .white }
    var defaultPack: KeyboardType { .default }
    // Provide stub values so keyboard target compiles without FirebaseRemoteConfig
    var enabledPacks: [KeyboardType] { KeyboardType.packs }
    var taxDefaultPercent: Int { 15 }
}
#endif

// MARK: - Clipboard History Manager

/// One stored clipboard entry. The capture timestamp drives TTL expiry so we never retain
/// copied content (which may include passwords, 2FA codes, card numbers) indefinitely.
private struct ClipboardEntry: Codable, Equatable {
    let text: String
    let date: Date
}

/// Minimal generic-password keychain wrapper. No `kSecAttrAccessGroup` is set, so items live in
/// the caller's default keychain access group — clipboard history is written and read only by the
/// keyboard extension, so it needs no shared access group (and thus no extra entitlement).
private enum KeychainStore {
    static func data(service: String, account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess else { return nil }
        return item as? Data
    }

    static func set(_ data: Data?, service: String, account: String) {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        guard let data = data else {
            SecItemDelete(base as CFDictionary)
            return
        }
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            // Device-only, never synced to iCloud; available to the background keyboard after
            // first unlock. Appropriate for short-lived, sensitive clipboard content.
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        if SecItemUpdate(base as CFDictionary, attributes as CFDictionary) == errSecItemNotFound {
            var add = base
            add.merge(attributes) { $1 }
            SecItemAdd(add as CFDictionary, nil)
        }
    }
}

class ClipboardHistoryManager {
    static let shared = ClipboardHistoryManager()
    // Clipboard content (which may include passwords, 2FA codes, card numbers) is stored in the
    // keychain rather than the shared UserDefaults plist, which is unencrypted on disk.
    private let service = "com.morevoltage.numpad.clipboardHistory"
    private let account = "history"
    private let legacyDefaultsKey = Constants.clipboardHistory.rawValue
    private let maxItems = 20
    /// Entries older than this are dropped on read and never shown. Clipboard content is
    /// sensitive, so history is intentionally short-lived rather than permanent.
    private let timeToLive: TimeInterval = 60 * 60 // 1 hour
    // Serializes read-modify-write within a process.
    private let lock = NSLock()

    private init() {
        migrateFromUserDefaultsIfNeeded()
    }

    /// One-time migration: move any pre-existing plaintext history out of the shared UserDefaults
    /// plist into the keychain, then delete the plaintext copy so it no longer lingers on disk.
    private func migrateFromUserDefaultsIfNeeded() {
        let defaults = UserDefaults.group
        guard let data = defaults.data(forKey: legacyDefaultsKey) else { return }
        if KeychainStore.data(service: service, account: account) == nil {
            KeychainStore.set(data, service: service, account: account)
        }
        defaults.removeObject(forKey: legacyDefaultsKey)
    }

    private var entries: [ClipboardEntry] {
        get {
            guard let data = KeychainStore.data(service: service, account: account) else { return [] }
            return (try? JSONDecoder().decode([ClipboardEntry].self, from: data)) ?? []
        }
        set {
            let data = try? JSONEncoder().encode(Array(newValue.prefix(maxItems)))
            KeychainStore.set(data, service: service, account: account)
        }
    }

    /// Non-expired history, most recent first. Returns empty if the user disabled the feature.
    var history: [String] {
        guard UserPrefs.clipboardHistoryEnabled else { return [] }
        let cutoff = Date().addingTimeInterval(-timeToLive)
        return entries.filter { $0.date >= cutoff }.map { $0.text }
    }

    func add(_ item: String) {
        guard UserPrefs.clipboardHistoryEnabled else { return }
        lock.lock(); defer { lock.unlock() }
        let cutoff = Date().addingTimeInterval(-timeToLive)
        var items = entries.filter { $0.date >= cutoff && $0.text != item }
        items.insert(ClipboardEntry(text: item, date: Date()), at: 0)
        entries = items
    }

    func clear() {
        lock.lock(); defer { lock.unlock() }
        KeychainStore.set(nil, service: service, account: account)
    }

    func remove(at index: Int) {
        lock.lock(); defer { lock.unlock() }
        let cutoff = Date().addingTimeInterval(-timeToLive)
        var items = entries.filter { $0.date >= cutoff }
        guard items.indices.contains(index) else { return }
        items.remove(at: index)
        entries = items
    }
}
