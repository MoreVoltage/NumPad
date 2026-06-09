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
    // Development-only entitlement simulation toggles (used by the DEBUG Store section only)
    case debugProOverride, debugForceLocked
    // Experimental feature flags — all OFF by default, surfaced for toggling only in
    // DEBUG/TestFlight builds (see FeatureFlags). Stored in the app group so the keyboard
    // extension reads the same value the app writes.
    case ffInlineCalculator, ffLocaleSeparators, ffCursorControls, ffConversionOverlay
    case ffLastResultTape, ffSaveSnippetFromKeyboard, ffICloudSync, ffSmartPackDefaulting
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
        case .symbols, .programmer, .tax:
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
            "packs_enabled": "math,math2,finance,symbols,programmer" as NSObject,
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
