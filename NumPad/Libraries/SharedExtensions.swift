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
        
//        static var red: UIColor { KeyboardTheme.isDarkMode ? red500 : red500 }
//        static var red500: UIColor { return UIColor(red: 244, green: 67, blue: 54) }
//        static var pink: UIColor { KeyboardTheme.isDarkMode ? pink500 : pink500 }
//        static var pink500: UIColor { return UIColor(red: 233, green: 30, blue: 99) }
//        static var purple: UIColor { KeyboardTheme.isDarkMode ? purple500 : purple500 }
//        static var purple500: UIColor { return UIColor(red: 156, green: 39, blue: 176) }
//        static var deepPurple: UIColor { KeyboardTheme.isDarkMode ? deepPurple500 : deepPurple500 }
//        static var deepPurple500: UIColor { return UIColor(red: 103, green: 58, blue: 183) }
//        static var indigo: UIColor { KeyboardTheme.isDarkMode ? indigo500 : indigo500 }
//        static var indigo500: UIColor { return UIColor(red: 63, green: 81, blue: 181) }
//        static var blue: UIColor { KeyboardTheme.isDarkMode ? blue500 : blue500 }
//        static var blue200: UIColor { return UIColor(red: 129, green: 212, blue: 250) }
//        static var blue500: UIColor { return UIColor(red: 33, green: 150, blue: 243) }
//        static var lightBlue: UIColor { KeyboardTheme.isDarkMode ? lightBlue500 : lightBlue500 }
//        static var lightBlue500: UIColor { return UIColor(red: 3, green: 169, blue: 244) }
//        static var teal: UIColor { KeyboardTheme.isDarkMode ? teal500 : teal500 }
//        static var teal500: UIColor { return UIColor(red: 0, green: 150, blue: 136) }
//        static var green: UIColor { KeyboardTheme.isDarkMode ? green500 : green500 }
//        static var green500: UIColor { return UIColor(red: 76, green: 175, blue: 80) }
//        static var lightGreen: UIColor { KeyboardTheme.isDarkMode ? lightGreen500 : lightGreen500 }
//        static var lightGreen500: UIColor { return UIColor(red: 139, green: 195, blue: 74) }
//        static var lime: UIColor { KeyboardTheme.isDarkMode ? lime500 : lime500 }
//        static var lime500: UIColor { return UIColor(red: 205, green: 220, blue: 57) }
//        static var yellow: UIColor { KeyboardTheme.isDarkMode ? yellow500 : yellow500 }
//        static var yellow500: UIColor { return UIColor(red: 255, green: 235, blue: 59) }
//        static var amber: UIColor { KeyboardTheme.isDarkMode ? amber500 : amber500 }
//        static var amber500: UIColor { return UIColor(red: 255, green: 193, blue: 7) }
//        static var orange: UIColor { KeyboardTheme.isDarkMode ? orange500 : orange500 }
//        static var orange500: UIColor { return UIColor(red: 255, green: 152, blue: 0) }
//        static var deepOrange: UIColor { KeyboardTheme.isDarkMode ? deepOrange500 : deepOrange500 }
//        static var deepOrange500: UIColor { return UIColor(red: 255, green: 87, blue: 34) }
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
    // Keyboard sizing & feature flags
    case adjustableKeyboardHeightEnabled
    case keyboardHeightCompact
    case keyboardHeightRegular
    // Live updates
    case liveKeyboardHeightAdjustEnabled
    // Ephemeral current height value sent while dragging (independent of size class)
    case currentKeyboardHeightLive
    // Ephemeral flag indicating the user is actively dragging the slider
    case isKeyboardHeightLiveAdjusting
}

// MARK: - Cross-process settings sync (App ↔︎ Keyboard Extension)
private var settingsSyncHandlers: [UnsafeMutableRawPointer: () -> Void] = [:]

enum SettingsSync {
    private static let notificationName = "com.morevoltage.numpad.settingsChanged"

    static func post() {
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFNotificationName(notificationName as CFString), nil, nil, true)
    }

    static func observe(_ observer: AnyObject, handler: @escaping () -> Void) {
        let key = Unmanaged.passUnretained(observer).toOpaque()
        settingsSyncHandlers[key] = handler
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
    guard let observer = observer, let handler = settingsSyncHandlers[observer] else { return }
    DispatchQueue.main.async { handler() }
}

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

// MARK: - Monetization Feature Flags

struct Monetization {
    @UserDefault(key: Constants.paywallEnabled.rawValue, defaultValue: false, userDefaults: .group)
    static var paywallEnabled: Bool

    // When paywall is disabled, everything should be accessible. Keep entitlement true by default for testing.
    @UserDefault(key: Constants.proEntitled.rawValue, defaultValue: true, userDefaults: .group)
    static var isProEntitled: Bool

    static func isFeatureLocked() -> Bool {
        return paywallEnabled && !isProEntitled
    }
}

// MARK: - User Preferences (Haptics / Sound)

struct UserPrefs {
    @UserDefault(key: Constants.hapticsEnabled.rawValue, defaultValue: true, userDefaults: .group)
    static var hapticsEnabled: Bool
    @UserDefault(key: Constants.soundEnabled.rawValue, defaultValue: true, userDefaults: .group)
    static var soundEnabled: Bool
    @UserDefault(key: "repurposeNextKey", defaultValue: true, userDefaults: .group)
    static var repurposeNextKey: Bool

    // Feature flag: when false (default), keyboard height stays system-like and non-adjustable
    @UserDefault(key: Constants.adjustableKeyboardHeightEnabled.rawValue, defaultValue: false, userDefaults: .group)
    static var adjustableKeyboardHeightEnabled: Bool

    // Persisted heights (stored as Double for UserDefaults compatibility). 0 means "not set".
    @UserDefault(key: Constants.keyboardHeightCompact.rawValue, defaultValue: 0.0, userDefaults: .group)
    static var keyboardHeightCompactValue: Double
    @UserDefault(key: Constants.keyboardHeightRegular.rawValue, defaultValue: 0.0, userDefaults: .group)
    static var keyboardHeightRegularValue: Double

    // When enabled, the keyboard should resize live as the user drags the slider in settings
    @UserDefault(key: Constants.liveKeyboardHeightAdjustEnabled.rawValue, defaultValue: true, userDefaults: .group)
    static var liveKeyboardHeightAdjustEnabled: Bool

    // Ephemeral: most recent slider value (used for live updates). 0 means "no live value".
    @UserDefault(key: Constants.currentKeyboardHeightLive.rawValue, defaultValue: 0.0, userDefaults: .group)
    static var currentKeyboardHeightLive: Double

    // Ephemeral: true while the user is dragging the slider
    @UserDefault(key: Constants.isKeyboardHeightLiveAdjusting.rawValue, defaultValue: false, userDefaults: .group)
    static var isKeyboardHeightLiveAdjusting: Bool
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

    private init() {}

    var snippets: [Snippet] {
        get {
            guard let data = userDefaults.data(forKey: key) else { return [] }
            return (try? JSONDecoder().decode([Snippet].self, from: data)) ?? []
        }
        set {
            let data = try? JSONEncoder().encode(newValue)
            userDefaults.set(data, forKey: key)
        }
    }

    func add(_ snippet: Snippet) {
        var items = snippets
        // De-duplicate by title
        items.removeAll { $0.title == snippet.title }
        items.insert(snippet, at: 0)
        snippets = items
    }

    func remove(at index: Int) {
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
            "packs_enabled": "math,math2,finance,symbols,programmer,tax" as NSObject,
            "tax_default_percent": 15 as NSNumber
        ]
        rc.setDefaults(defaults)
    }

    func fetchAndActivate() {
        rc.fetchAndActivate(completionHandler: { _, _ in })
    }

    var priceCopy: String { rc["price_copy"].stringValue ?? "" }
    var defaultTheme: KeyboardTheme { KeyboardTheme(rawValue: rc["default_theme"].stringValue ?? "white") ?? .white }
    var defaultPack: KeyboardType { KeyboardType(rawValue: rc["default_pack"].stringValue ?? "default") ?? .default }
    var enabledPacks: [KeyboardType] {
        let csv = rc["packs_enabled"].stringValue ?? ""
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

class ClipboardHistoryManager {
    static let shared = ClipboardHistoryManager()
    private let userDefaults = UserDefaults.group
    private let historyKey = "clipboardHistory"
    private let maxItems = 20
    
    private init() {}
    
    var history: [String] {
        get {
            return userDefaults.stringArray(forKey: historyKey) ?? []
        }
        set {
            userDefaults.set(Array(newValue.prefix(maxItems)), forKey: historyKey)
        }
    }
    
    func add(_ item: String) {
        var items = history
        // Remove duplicates (keep most recent)
        items.removeAll { $0 == item }
        items.insert(item, at: 0)
        history = items
    }
    
    func clear() {
        history = []
    }
    
    func remove(at index: Int) {
        var items = history
        guard items.indices.contains(index) else { return }
        items.remove(at: index)
        history = items
    }
}
