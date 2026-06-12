//
//  SharedExtensions.swift
//  NumPad
//
//  Created by Lasha Efremidze on 3/9/17.
//  Copyright © 2017 MoreVoltage. All rights reserved.
//

import UIKit
import CoreFoundation
import TinyConstraints

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
    case reversedMode, roundedCorners, grid, selectedKeyboardType, selectedKeyboardTheme, automaticDarkMode, paywallEnabled, proEntitled, snippets, hapticsEnabled, soundEnabled, rcApplied
    // Behavior toggles (were previously inline string literals)
    case repurposeNextKey, clipboardHistory, clipboardHistoryEnabled
    // StoreKit 2 purchases (written only by the app; the keyboard extension reads them)
    case proPurchased, financePackPurchased, grandfathered, grandfatherChecked
    // Development-only entitlement simulation toggles (used by the DEBUG Store section only)
    case debugProOverride, debugForceLocked
    // Customizable keys: the three remappable right-side slots and the user-built Custom pack
    case customKeySlots, customPackKeys
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
    /// purchases (dev/TestFlight builds report originalAppVersion "1.0", so every test device is
    /// grandfathered and could otherwise never see lock chips). Takes precedence over everything.
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

    private init() {}

    var snippets: [Snippet] {
        get {
            guard let data = userDefaults.data(forKey: key) else { return [] }
            return (try? JSONDecoder().decode([Snippet].self, from: data)) ?? []
        }
        set {
            let data = try? JSONEncoder().encode(Array(newValue.prefix(maxItems)))
            userDefaults.set(data, forKey: key)
        }
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

    static let slotCount = 3
    static let maxTokenLength = 4
    static let defaultSlots = [",", ".", spaceToken]

    /// Tokens offered by the app's key palette (plus free-form input).
    static let palette = [",", ".", spaceToken, tabToken, "-", "+", "=", "%", "$", ":", ";", "/", "(", ")", "#", "00", "000"]

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
        default: return token
        }
    }

    /// The text a token inserts into the host app.
    static func insertedText(for token: String) -> String {
        switch token {
        case spaceToken: return " "
        case tabToken: return "\t"
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
            "packs_enabled": "math,math2,finance,symbols,programmer,tax,custom" as NSObject,
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

class ClipboardHistoryManager {
    static let shared = ClipboardHistoryManager()
    private let userDefaults = UserDefaults.group
    private let historyKey = Constants.clipboardHistory.rawValue
    private let maxItems = 20
    /// Entries older than this are dropped on read and never shown. Clipboard content is
    /// sensitive, so history is intentionally short-lived rather than permanent.
    private let timeToLive: TimeInterval = 60 * 60 // 1 hour
    // Serializes read-modify-write within a process.
    private let lock = NSLock()

    private init() {}

    private var entries: [ClipboardEntry] {
        get {
            guard let data = userDefaults.data(forKey: historyKey) else { return [] }
            return (try? JSONDecoder().decode([ClipboardEntry].self, from: data)) ?? []
        }
        set {
            let data = try? JSONEncoder().encode(Array(newValue.prefix(maxItems)))
            userDefaults.set(data, forKey: historyKey)
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
        userDefaults.removeObject(forKey: historyKey)
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
