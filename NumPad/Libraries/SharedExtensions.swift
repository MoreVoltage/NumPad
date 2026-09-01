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
        // Liquid Glass premium themes. Deliberately translucent (unlike every other swatch above)
        // so the *same* color doubles as the <iOS 26 fallback (a tasteful translucent-gray look
        // wherever it's composited) and as the base tint for the real iOS 26 glass material —
        // `isLight()` (luminance-only, alpha-blind) still resolves black/white foreground text
        // correctly, and `.lighter`/`.darkened` preserve the alpha through derived shades.
        static var glass: UIColor { return UIColor(white: 0.93, alpha: 0.55) }
        static var glassDark: UIColor { return UIColor(white: 0.08, alpha: 0.55) }
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
    // One-time first-run upsell: the contextual paywall shown once after the keyboard is enabled.
    case firstRunUpsellShown
    // Behavior toggles (were previously inline string literals)
    case repurposeNextKey, clipboardHistory, clipboardHistoryEnabled
    // StoreKit 2 purchases (written only by the app; the keyboard extension reads them)
    case proPurchased, financePackPurchased, customKeyboardPurchased, grandfathered, grandfatherChecked
    // v2 re-runs the grandfather check with the AppTransaction.environment guard, clearing
    // bogus sandbox-derived grandfathering cached under the v1 key (App Review / TestFlight
    // installs where originalAppVersion is always "1.0").
    case grandfatherCheckedV2
    // Development-only entitlement simulation toggles (used by the DEBUG Store section only)
    case debugProOverride, debugForceLocked
    // DEBUG screenshot helper: keyboard seeds sample clipboard-history rows on next overlay present
    case debugSeedClipboard
    // Customizable keys: the three remappable right-side slots and the user-built Custom pack
    case customKeySlots, customPackKeys
    // 2.0 structured custom keyboard (v2): the active CustomKeyboardConfig (JSON) and the global
    // left/right-handed setting that places the customizable columns on the handed side.
    case customKeyboardConfig, handedness
    // Keyboard height preset (small / regular / tall) on iPhone
    case heightPreset
    // GA keyboard-behavior preferences (promoted from experimental flags in 2.0; default ON,
    // user-toggleable, available in all builds). Distinct keys from the old ff* flags so the
    // default flips to ON cleanly for everyone.
    case inlineCalculatorEnabled, cursorControlsEnabled, smartPackDefaultingEnabled, lastResultTapeEnabled
    // iCloud sync (Pro feature) — user opt-in toggle, default OFF.
    case iCloudSyncEnabled
    // 2.0 à la carte packs: the set of owned pack product IDs (written by StoreManager).
    case ownedPackProductIDs
    // Early-bird Pro promo (72h discounted Pro for pre-2.0 users).
    case firstV2LaunchTimestamp, earlyBirdEligibleUser, earlyBirdInitialized
    // Whether the in-app notifications pre-prompt has been shown (gates the system dialog; shown once).
    case updatesPrepromptShown
    // Experimental feature flags — all OFF by default, surfaced for toggling only in
    // DEBUG/TestFlight builds (see FeatureFlags). Stored in the app group so the keyboard
    // extension reads the same value the app writes.
    case ffInlineCalculator, ffLocaleSeparators, ffCursorControls, ffConversionOverlay
    case ffLastResultTape, ffSaveSnippetFromKeyboard, ffICloudSync, ffSmartPackDefaulting
    case ffBackspaceWordDelete
    // Escape hatch for the Custom Keyboard editor's Option B drag-reorder UI (default ON, unlike
    // the ff* flags above — see FeatureFlags.customKeyboardDragReorderEnabled).
    case customKeyboardDragReorderEnabled
    // Data backing for experimental features
    case resultTape
    // Keyboard-enablement funnel tracking + the two proactive first-run paywalls (early-bird uses
    // firstRunUpsellShown above; new-buyer has its own flag so the funnels never conflate).
    case keyboardEnablementBaselineEstablished, keyboardEnabledLastKnown, keyboardEnabledEventLogged
    case newBuyerUpsellDeferredTrigger, newBuyerUpsellShown
    // Persists a live false->true transition until the new-buyer upsell is actually presented, so a
    // presentation-guard failure at fire time (e.g. another modal on screen 0.6s later) retries on
    // the next foreground instead of burning the one-shot trigger forever.
    case newBuyerUpsellTriggerPending
    // Session-count milestone upsell (RC `upsell_after_sessions`), shown at most once.
    case sessionCount, sessionMilestoneUpsellShown
    // Keyboard lock-funnel counters (extension has no Firebase); flushed to one analytics event
    // per app foreground.
    case lockImpressions, lockedKeyTaps, storeDeeplinkOpens
    // Live Math Preview (compute-as-you-type result chip): the user-facing GA toggle, and the
    // Remote Config kill switch mirrored into the app group so the keyboard extension — which has
    // no Firebase Remote Config of its own — can read it directly (see RemoteConfigManager /
    // LiveMathPreview). Plus its own pair of extension counters, flushed the same way as
    // lockImpressions/lockedKeyTaps/storeDeeplinkOpens above.
    case liveMathPreviewEnabled, mathPreviewRemoteEnabled, mathPreviewShown, mathPreviewInserted
    // Key-press micro-interaction (press-down scale/brightness dip + spring release): the local
    // escape hatch (default ON, like customKeyboardDragReorderEnabled above — this gates a shipped
    // visual, not an opt-in experiment) and the Remote Config kill switch mirrored into the app
    // group, since the Keyboard extension — which actually renders the animation — has no Firebase
    // Remote Config of its own (mirrors the Live Math Preview pattern above).
    case keyPressAnimationEnabled, keyPressAnimationRemoteEnabled
    // App Intents (Siri / Shortcuts / Spotlight): local escape hatch, default ON like
    // customKeyboardDragReorderEnabled above — this gates a shipped system integration, not an
    // opt-in experiment. App-side only (no Keyboard extension involvement), so unlike the mirrored
    // pairs above there's no *RemoteEnabled twin — the Remote Config value is read directly at the
    // call site (see RemoteConfigManager.appIntentsEnabled).
    case appIntentsEnabled
    // Interactive first-run onboarding (WOW / ENABLE / TRY IT), shown once on fresh installs before
    // the legacy Instructions push. One-shot flag, consumed only when onboarding is actually
    // presented (see OnboardingFlow.markShown). App-side only, like appIntentsEnabled above — no
    // Keyboard extension involvement, so the RC kill switch (`onboarding_enabled`) is read directly
    // from RemoteConfigManager with no mirrored twin.
    case onboardingShown
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

// MARK: - Product catalog (2.0 paid app + IAP ladder)

/// Single source of truth for StoreKit product IDs and the pack ↔ product mapping. Lives in the
/// shared file so the keyboard extension (gating) and the app (StoreManager) agree. 2.0 model:
/// the app is a paid download whose **base** is default/math/math2; the other packs are $1.99
/// à la carte non-consumables; the custom-keys pack is Pro-only; Pro ($11.99) unlocks everything.
enum ProductCatalog {
    static let pro = "numpad.pro.lifetime"
    /// 50%-off Pro for grandfathered users in their 72h early-bird window. Grants identical Pro.
    static let proEarlyBird = "numpad.pro.lifetime.earlybird"

    /// The à la carte product ID for a pack, or `nil` for base packs (free) and Pro-only packs.
    static func packProductID(for pack: KeyboardType) -> String? {
        switch pack {
        case .default, .math, .math2: return nil          // base — included in the paid download
        case .finance:        return "numpad.pack.finance"
        case .symbols:        return "numpad.pack.symbols"
        case .programmer:     return "numpad.pack.programmer"
        case .datetime:       return "numpad.pack.datetime"
        case .units:          return "numpad.pack.units"
        case .cooking:        return "numpad.pack.cooking"
        // 2.0: curated to the seven-pack catalog — these domains are no longer sold à la carte.
        // The enum cases remain so any stale persisted selection still decodes (no pack row).
        case .scientific, .business, .international, .programmerPlus: return nil
        case .tax, .custom:   return nil                  // tax not selectable; custom is Pro-only
        }
    }

    static func isBasePack(_ pack: KeyboardType) -> Bool {
        switch pack { case .default, .math, .math2: return true; default: return false }
    }

    /// Packs available only via Pro (no standalone purchase): the user-built custom-keys pack.
    static func isProOnlyPack(_ pack: KeyboardType) -> Bool {
        switch pack { case .custom: return true; default: return false }
    }

    /// All à la carte pack product IDs (the selectable, non-base, non-Pro-only packs).
    static var allPackProductIDs: [String] {
        KeyboardType.packs.compactMap { packProductID(for: $0) }
    }

    /// Every product the app sells, for StoreKit loading.
    static var allProductIDs: [String] {
        [pro, proEarlyBird] + allPackProductIDs
    }
}

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
        guard paywallEnabled else { return false }
        #if DEBUG
        if debugForceLocked { return !ProductCatalog.isBasePack(pack) }
        #endif
        if isProEntitled { return false } // Pro, grandfathered, or the debug Pro override
        return isPackLocked(pack, proEntitled: false, ownedPackProductIDs: effectiveOwnedPackProductIDs)
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

    // MARK: 2.0 à la carte ownership

    /// Product IDs of à la carte packs the user owns (written by StoreManager from StoreKit
    /// entitlements; read by the keyboard for gating).
    @UserDefault(key: Constants.ownedPackProductIDs.rawValue, defaultValue: [], userDefaults: .group)
    private static var ownedPackProductIDsArray: [String]
    static var ownedPackProductIDs: Set<String> {
        get { Set(ownedPackProductIDsArray) }
        set { ownedPackProductIDsArray = Array(newValue).sorted() }
    }

    /// Owned pack IDs including the legacy Finance bool, so 1.x finance buyers stay unlocked before
    /// the next StoreKit entitlement refresh migrates them into the set.
    private static var effectiveOwnedPackProductIDs: Set<String> {
        var owned = ownedPackProductIDs
        if isFinancePackPurchased, let finance = ProductCatalog.packProductID(for: .finance) {
            owned.insert(finance)
        }
        return owned
    }

    /// Pure 2.0 gate: base packs are free; Pro/grandfathered unlocks everything; the custom-keys
    /// pack is Pro-only; every other pack is unlocked only when its product is owned. Self-contained
    /// (all state passed in) so it can be unit-tested without touching UserDefaults.
    static func isPackLocked(_ pack: KeyboardType, proEntitled: Bool, ownedPackProductIDs: Set<String>) -> Bool {
        if ProductCatalog.isBasePack(pack) { return false }
        if proEntitled { return false }
        if ProductCatalog.isProOnlyPack(pack) { return true }
        guard let id = ProductCatalog.packProductID(for: pack) else { return false }
        return !ownedPackProductIDs.contains(id)
    }

    /// Whether the long-press "=" conversion overlay should be reachable right now: either the
    /// caller is entitled to a pack that surfaces real conversion through it — Units & Conversion
    /// (length/mass/temperature) or Cooking & Baking (its cups↔ml volume category, same overlay,
    /// same `UnitConverter`) — expressed by the caller passing that pack's `...Locked: false`, or
    /// the experimental flag is on (kept for un-entitled DEBUG/TestFlight testers to exercise the
    /// overlay without buying either pack). Self-contained (all state passed in) so it's
    /// unit-testable without touching UserDefaults.
    static func isConversionOverlayReachable(experimentalFlagOn: Bool, unitsPackLocked: Bool, cookingPackLocked: Bool) -> Bool {
        return experimentalFlagOn || !unitsPackLocked || !cookingPackLocked
    }

    /// The set of `UnitConverter.Category` the conversion overlay may actually reveal, scoped to
    /// what was bought — a Units & Conversion-only buyer must not get Cooking & Baking's volume
    /// converter for free, and vice versa. Pro/grandfathered (both `...Locked` args false) or the
    /// un-entitled DEBUG/TestFlight experimental flag unlocks every category; otherwise Units &
    /// Conversion unlocks the non-volume categories (length/mass/temperature) and Cooking & Baking
    /// unlocks `.volume`; owning both unions the sets. Self-contained (all state passed in) so it's
    /// unit-testable without touching UserDefaults — mirrors `isConversionOverlayReachable` above.
    static func entitledConversionCategories(experimentalFlagOn: Bool,
                                              unitsPackLocked: Bool,
                                              cookingPackLocked: Bool) -> Set<UnitConverter.Category> {
        if experimentalFlagOn { return Set(UnitConverter.Category.allCases) }
        var categories: Set<UnitConverter.Category> = []
        if !unitsPackLocked {
            categories.formUnion(UnitConverter.Category.allCases.filter { $0 != .volume })
        }
        if !cookingPackLocked {
            categories.insert(.volume)
        }
        return categories
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

    // GA keyboard-behavior features (promoted from experimental flags in 2.0). Default ON for all
    // users; the keyboard reads these directly with no experimentalUIVisible gate. These are free.
    @UserDefault(key: Constants.inlineCalculatorEnabled.rawValue, defaultValue: true, userDefaults: .group)
    static var inlineCalculator: Bool
    @UserDefault(key: Constants.cursorControlsEnabled.rawValue, defaultValue: true, userDefaults: .group)
    static var cursorControls: Bool
    @UserDefault(key: Constants.smartPackDefaultingEnabled.rawValue, defaultValue: true, userDefaults: .group)
    static var smartPackDefaulting: Bool
    @UserDefault(key: Constants.lastResultTapeEnabled.rawValue, defaultValue: true, userDefaults: .group)
    static var lastResultTape: Bool
    // Live Math Preview: the floating "= result" chip shown while typing an expression in any app.
    // Default ON (zero-cost when idle — the whole feature is gated behind a cheap last-character
    // guard before any parsing happens). Independent of `inlineCalculator`: a user can keep the
    // passive preview while leaving the "=" key's active evaluation off, or vice versa.
    @UserDefault(key: Constants.liveMathPreviewEnabled.rawValue, defaultValue: true, userDefaults: .group)
    static var liveMathPreview: Bool

    // iCloud sync (Pro). Default OFF — an explicit opt-in; additionally gated by Pro + capability at
    // the CloudSync use site.
    @UserDefault(key: Constants.iCloudSyncEnabled.rawValue, defaultValue: false, userDefaults: .group)
    static var iCloudSyncEnabled: Bool

    // 2.0 structured custom keyboard: which side the customizable peripheral columns sit on. A
    // global (ergonomic) setting — app group + SettingsSync — that the keyboard extension reads
    // when rendering a custom keyboard. Default right-handed.
    @UserDefault(key: Constants.handedness.rawValue, defaultValue: Handedness.default.rawValue, userDefaults: .group)
    private static var _handedness: String
    static var handedness: Handedness {
        get { Handedness(rawValue: _handedness) ?? .default }
        set { _handedness = newValue.rawValue }
    }
}

// MARK: - Experimental Feature Flags
//
// Every new (post-1.7.0) capability is gated behind one of these flags and ships **OFF by
// default**, so production behavior is unchanged until a flag is explicitly enabled. The toggles
// are only *surfaced* in DEBUG and TestFlight builds (`experimentalUIVisible`); App Store users
// never see them. Flags live in the shared app group so the keyboard extension reads the same
// value the container app writes (followed by `SettingsSync.post()` so a live keyboard reacts).
struct FeatureFlags {
    @UserDefault(key: Constants.ffLocaleSeparators.rawValue, defaultValue: false, userDefaults: .group)
    private static var storedLocaleAwareSeparators: Bool

    @UserDefault(key: Constants.ffConversionOverlay.rawValue, defaultValue: false, userDefaults: .group)
    private static var storedConversionOverlay: Bool

    @UserDefault(key: Constants.ffSaveSnippetFromKeyboard.rawValue, defaultValue: false, userDefaults: .group)
    private static var storedSaveSnippetFromKeyboard: Bool

    @UserDefault(key: Constants.ffBackspaceWordDelete.rawValue, defaultValue: false, userDefaults: .group)
    private static var storedBackspaceWordDelete: Bool

    /// Escape hatch for the Custom Keyboard editor's Option B drag-reorder UI
    /// (`CustomKeyboardSectionReorderView`, a `UICollectionView` bridged into SwiftUI). Unlike every
    /// flag above, this ships ON by default to everyone — App Store included — because it gates the
    /// *shipping* editor UI, not an opt-in experiment. Its raw stored value is read directly
    /// wherever the editor checks it and is deliberately NOT passed through `effective()`
    /// (`experimentalUIVisible` would otherwise force it off in production builds). Only the
    /// toggle's *visibility* in the Feature Flags (Beta) section piggybacks on that same gate, so
    /// only DEBUG/TestFlight builds can flip it — the point is to let a device-only failure be
    /// reverted to the legacy static slot rows in TestFlight without a code change (see
    /// docs/plans/2026-07-03-editor-ux-research.md).
    @UserDefault(key: Constants.customKeyboardDragReorderEnabled.rawValue, defaultValue: true, userDefaults: .group)
    static var customKeyboardDragReorderEnabled: Bool

    /// Local escape hatch for the key-press micro-interaction (press-down scale/brightness dip +
    /// spring release, `Button._isHighlighted`). Ships ON by default to everyone — App Store
    /// included — like `customKeyboardDragReorderEnabled` above, because it gates shipped visual
    /// polish, not an opt-in experiment; deliberately NOT passed through `effective()`. Combine
    /// with the Remote Config kill switch via `keyPressAnimationActive`.
    @UserDefault(key: Constants.keyPressAnimationEnabled.rawValue, defaultValue: true, userDefaults: .group)
    static var keyPressAnimation: Bool

    /// Mirrored copy of the `key_press_animation_enabled` Remote Config value (see
    /// `RemoteConfigManager.mirrorKeyPressAnimationKillSwitch`), since the Keyboard extension has
    /// no Firebase Remote Config of its own. Defaults true so behavior is unchanged until the app
    /// has fetched at least once.
    @UserDefault(key: Constants.keyPressAnimationRemoteEnabled.rawValue, defaultValue: true, userDefaults: .group)
    static var keyPressAnimationRemoteEnabled: Bool

    /// Pure combinator: both the remote kill switch and the local toggle must be on. Self-contained
    /// (all state passed in) so it's unit-testable without touching UserDefaults or Remote Config.
    /// Mirrors `LiveMathPreview.isActive` / `dragReorderActive` above.
    static func keyPressAnimationActive(remoteEnabled: Bool, localEnabled: Bool) -> Bool {
        return remoteEnabled && localEnabled
    }

    /// Convenience reading the live stored values — what call sites (`Button`) actually use.
    static var isKeyPressAnimationActive: Bool {
        keyPressAnimationActive(remoteEnabled: keyPressAnimationRemoteEnabled, localEnabled: keyPressAnimation)
    }

    /// Production kill switch for the drag-reorder UI: ANDs the local escape hatch above with a
    /// Remote Config value, so a device-only failure (the class of bug that killed the prior
    /// springboard editor) can be reverted for everyone — App Store included — without an app
    /// release, even though the local flag itself defaults ON and isn't TestFlight/DEBUG-gated.
    /// Self-contained (all state passed in) so it's unit-testable without touching Remote Config.
    static func dragReorderActive(remoteConfigEnabled: Bool, localFlagEnabled: Bool) -> Bool {
        return remoteConfigEnabled && localFlagEnabled
    }

    /// Local escape hatch for App Intents (Siri/Shortcuts/Spotlight). Ships ON by default to
    /// everyone — App Store included — like `customKeyboardDragReorderEnabled`/`keyPressAnimation`
    /// above, because it gates a shipped integration, not an opt-in experiment. Deliberately NOT
    /// passed through `effective()` (that would force it off in production builds).
    @UserDefault(key: Constants.appIntentsEnabled.rawValue, defaultValue: true, userDefaults: .group)
    static var appIntentsEnabled: Bool

    /// Production kill switch for App Intents: ANDs the local escape hatch above with a Remote
    /// Config value, so a bad Siri/Shortcuts integration can be reverted for everyone without an
    /// app release. Self-contained (all state passed in) so it's unit-testable without touching
    /// Remote Config. Mirrors `dragReorderActive` / `keyPressAnimationActive` above.
    static func appIntentsActive(remoteEnabled: Bool, localEnabled: Bool) -> Bool {
        return remoteEnabled && localEnabled
    }

    /// Convenience reading the live stored values — what each `AppIntent.perform()` actually uses.
    /// App Intents are app-side only (no Keyboard extension involvement), so the Remote Config side
    /// is read directly here with no mirroring step needed (see `RemoteConfigManager.appIntentsEnabled`).
    static var isAppIntentsActive: Bool {
        appIntentsActive(remoteEnabled: RemoteConfigManager.shared.appIntentsEnabled, localEnabled: appIntentsEnabled)
    }

    static func isExperimentalFlagEnabled(stored: Bool,
                                          uiVisible: Bool,
                                          capabilityAvailable: Bool = true) -> Bool {
        return stored && uiVisible && capabilityAvailable
    }

    private static func effective(_ stored: Bool, capabilityAvailable: Bool = true) -> Bool {
        return isExperimentalFlagEnabled(stored: stored,
                                         uiVisible: experimentalUIVisible,
                                         capabilityAvailable: capabilityAvailable)
    }

    static var localeAwareSeparators: Bool {
        get { effective(storedLocaleAwareSeparators) }
        set { storedLocaleAwareSeparators = newValue }
    }

    static var conversionOverlay: Bool {
        get { effective(storedConversionOverlay) }
        set { storedConversionOverlay = newValue }
    }

    static var saveSnippetFromKeyboard: Bool {
        get { effective(storedSaveSnippetFromKeyboard) }
        set { storedSaveSnippetFromKeyboard = newValue }
    }

    static var backspaceWordDelete: Bool {
        get { effective(storedBackspaceWordDelete) }
        set { storedBackspaceWordDelete = newValue }
    }

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
        let flags = [
            Flag(title: NSLocalizedString("Locale-Aware Separators", comment: "Feature flag"),
                 subtitle: NSLocalizedString("Use your region's decimal separator", comment: "Feature flag detail"),
                 get: { localeAwareSeparators }, set: { localeAwareSeparators = $0; SettingsSync.post() }),
            Flag(title: NSLocalizedString("Conversion Overlay", comment: "Feature flag"),
                 subtitle: NSLocalizedString("Quick offline unit conversions", comment: "Feature flag detail"),
                 get: { conversionOverlay }, set: { conversionOverlay = $0; SettingsSync.post() }),
            Flag(title: NSLocalizedString("Save Snippet From Keyboard", comment: "Feature flag"),
                 subtitle: NSLocalizedString("Save the last result as a snippet", comment: "Feature flag detail"),
                 get: { saveSnippetFromKeyboard }, set: { saveSnippetFromKeyboard = $0; SettingsSync.post() }),
            Flag(title: NSLocalizedString("Fast Delete", comment: "Feature flag"),
                 subtitle: NSLocalizedString("Held backspace deletes whole numbers and words", comment: "Feature flag detail"),
                 get: { backspaceWordDelete }, set: { backspaceWordDelete = $0; SettingsSync.post() }),
            // On by default (see the property doc comment) — turning this OFF is the escape
            // hatch, reverting the Custom Keyboard editor to the legacy static slot rows.
            Flag(title: NSLocalizedString("Custom Keyboard Drag Reorder", comment: "Feature flag"),
                 subtitle: NSLocalizedString("Drag to reorder keys in the Custom Keyboard editor. Turn off to revert to tap-to-edit rows.", comment: "Feature flag detail"),
                 get: { customKeyboardDragReorderEnabled }, set: { customKeyboardDragReorderEnabled = $0; SettingsSync.post() }),
            // On by default (see the property doc comment) — turning this OFF is the escape
            // hatch, reverting keys to the classic instant highlight with no press animation.
            Flag(title: NSLocalizedString("Key Press Animation", comment: "Feature flag"),
                 subtitle: NSLocalizedString("Subtle press-down animation on each key tap. Turn off to use the classic instant highlight.", comment: "Feature flag detail"),
                 get: { keyPressAnimation }, set: { keyPressAnimation = $0; SettingsSync.post() }),
        ]
        return flags
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

// MARK: - Text deletion (backspace escalation)

/// Pure helper for the fast-delete feature: how many trailing characters form one "chunk".
/// A chunk is a run of the same character class — number (digits with separators), letters,
/// or whitespace; any other symbol deletes singly. Capped so a single escalated backspace
/// never wipes an unbounded amount of text.
enum TextDeletion {
    static let maxChunk = 20

    static func trailingChunkLength(of text: String) -> Int {
        guard let last = text.last else { return 0 }
        let numeric = Set("0123456789.,")
        let inSameClass: (Character) -> Bool
        if last.isWhitespace {
            inSameClass = { $0.isWhitespace }
        } else if numeric.contains(last) {
            inSameClass = { numeric.contains($0) }
        } else if last.isLetter {
            inSameClass = { $0.isLetter }
        } else {
            return 1
        }
        let runLength = text.reversed().prefix(while: inSameClass).count
        return min(max(runLength, 1), maxChunk)
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

    /// Given a total that already includes tax, back out the pre-tax subtotal that `total`/
    /// `tipOnly` expect for their `amount` parameter (e.g. a Siri "the bill was $54, tax's already
    /// in there" phrasing). Guards against a nonsensical `taxRate <= -1` (would divide by zero or
    /// invert the sign) by clamping to the un-adjusted total instead of returning `.infinity`/NaN.
    static func preTaxAmount(fromTaxInclusiveTotal total: Double, taxRate: Double) -> Double {
        guard taxRate > -1 else { return total }
        return total / (1 + taxRate)
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
        /// A numeric literal immediately followed by `%` (e.g. the `20%` in `250 - 20%`). Kept
        /// distinct from `.number` so `evalRPN` can apply percent-natural math: `+`/`-` treat it as
        /// a percentage *of the running left-hand operand* (the receipt-math convention — see
        /// `evalRPN`), `*`/`/` treat it as a plain fraction (÷100), and a lone percent value with no
        /// enclosing binary op (e.g. a bare "20%") is also a plain fraction.
        case percent(Double)
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
            case "+", "-", "*", "/":
                tokens.append(.op(c))
            case "%":
                // Percent only ever suffixes the number immediately before it (whitespace between
                // them is fine — "20 %" parses the same as "20%"). "%" after anything else (an
                // operator, a paren, or another "%") isn't percent-natural syntax we understand, so
                // reject rather than silently guessing.
                guard case .number(let d)? = tokens.last else { return nil }
                tokens[tokens.count - 1] = .percent(d)
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
        case "*", "/": return 2
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
            case .number, .percent:
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

    /// An RPN operand: its numeric value, and whether it came from a `%`-suffixed literal (so the
    /// operator that consumes it knows whether to apply percent-natural math).
    private struct Operand {
        let value: Double
        let isPercent: Bool
    }

    /// Evaluating the RPN stream left-to-right naturally gives each operator the *current running
    /// value* of its left-hand side — exactly what's needed to make chained percentages compound
    /// correctly (e.g. "100 - 10% - 10%" → 100 → 90 → 81, each % taken against the running total).
    private static func evalRPN(_ rpn: [Token]) -> Double? {
        var stack: [Operand] = []
        for token in rpn {
            switch token {
            case .number(let d):
                stack.append(Operand(value: d, isPercent: false))
            case .percent(let d):
                stack.append(Operand(value: d, isPercent: true))
            case .op(let o):
                if o == "~" {
                    guard let a = stack.popLast() else { return nil }
                    stack.append(Operand(value: -a.value, isPercent: a.isPercent))
                    break
                }
                guard stack.count >= 2 else { return nil }
                let b = stack.removeLast(); let a = stack.removeLast()
                // Percent-natural math: "+"/"-" treat a %-suffixed right-hand side as a percentage
                // *of the left-hand operand* (e.g. "250 - 20%" = 250 - 250×0.2 = 200, the receipt
                // convention); "*"/"/" treat it as a plain fraction (e.g. "50 * 20%" = 50 × 0.2 = 10),
                // matching how a physical calculator's % key behaves.
                let bValue: Double
                switch o {
                case "+", "-": bValue = b.isPercent ? a.value * (b.value / 100) : b.value
                case "*", "/": bValue = b.isPercent ? b.value / 100 : b.value
                default: bValue = b.value
                }
                switch o {
                case "+": stack.append(Operand(value: a.value + bValue, isPercent: false))
                case "-": stack.append(Operand(value: a.value - bValue, isPercent: false))
                case "*": stack.append(Operand(value: a.value * bValue, isPercent: false))
                case "/":
                    guard bValue != 0 else { return nil }
                    stack.append(Operand(value: a.value / bValue, isPercent: false))
                default: return nil
                }
            default:
                return nil
            }
        }
        guard stack.count == 1, let result = stack.first else { return nil }
        // A lone percent value with no enclosing binary op (e.g. a bare "20%") is a plain fraction.
        return result.isPercent ? result.value / 100 : result.value
    }
}

// MARK: - Unit Converter (offline conversions)

/// Pure, offline unit conversion for the conversion-overlay feature. Length and mass go through a
/// linear base-unit factor; temperature is handled specially (affine, not linear). No network — so
/// currency is intentionally out of scope (it needs live rates a keyboard extension can't fetch).
enum UnitConverter {

    enum Category: String, CaseIterable {
        case length, mass, temperature, volume
        var displayName: String {
            switch self {
            case .length: return NSLocalizedString("Length", comment: "Conversion category")
            case .mass: return NSLocalizedString("Mass", comment: "Conversion category")
            case .temperature: return NSLocalizedString("Temperature", comment: "Conversion category")
            case .volume: return NSLocalizedString("Volume", comment: "Conversion category")
            }
        }
        /// Units in this category, in display order. The first two are the default from/to pair.
        var units: [String] {
            switch self {
            case .length: return ["cm", "in", "m", "ft", "km", "mi"]
            case .mass: return ["kg", "lb", "g", "oz"]
            case .temperature: return ["°C", "°F"]
            // Cup/ml first so the overlay defaults to the cups↔ml pairing the Cooking & Baking
            // pack is sold on; tbsp/tsp are the finer-grained recipe units.
            case .volume: return ["cup", "ml", "tbsp", "tsp"]
            }
        }
    }

    /// Each linear unit's category and factor to its category's base unit (meters / kilograms /
    /// milliliters). Tagging the category lets `convert` reject cross-category requests (e.g.
    /// metres → kilograms).
    private static let unitInfo: [String: (category: Category, factor: Double)] = [
        // length → meters
        "cm": (.length, 0.01), "in": (.length, 0.0254), "m": (.length, 1),
        "ft": (.length, 0.3048), "km": (.length, 1000), "mi": (.length, 1609.344),
        // mass → kilograms
        "kg": (.mass, 1), "lb": (.mass, 0.45359237), "g": (.mass, 0.001), "oz": (.mass, 0.028349523125),
        // volume → milliliters (US customary cooking measures)
        "ml": (.volume, 1), "cup": (.volume, 236.5882365),
        "tbsp": (.volume, 14.78676478125), "tsp": (.volume, 4.92892159375)
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

// MARK: - Pack key catalog (pure, unit-tested)

/// The literal key rows for the symbol/operator packs, kept pure and shared so they can be
/// unit-tested. (The `Item.pack(type:)` layout that consumes them lives in the Keyboard target,
/// which the test target can't see; this enum lives in the shared file, like `Calculator` and
/// `UnitConverter`.) Computed packs — date/time and international — derive their values at tap time
/// and are handled in the keyboard's tap dispatch, not here.
enum PackKeys {
    /// The ordered key labels for a symbol pack, or `[]` for packs that aren't simple symbol rows
    /// (default / math / computed packs).
    static func symbols(for type: KeyboardType) -> [String] {
        switch type {
        case .units:          return ["cm", "m", "km", "in", "ft", "mi", "kg", "lb", "°C", "°F"]
        case .cooking:        return ["½", "⅓", "¼", "⅔", "¾", "⅛", "tsp", "tbsp", "cup", "ml"]
        case .scientific:     return ["π", "e", "√", "^", "²", "³", "×", "÷", "±", "°"]
        case .business:       return ["$", "€", "£", "¥", "¢", "%", "‰", "(", ")", "#"]
        case .programmerPlus: return ["0b", "!=", "==", "&&", "||", "=>", "->", "{", "}", "_"]
        case .international:   return ["€", "£", "¥", "₹", "₩", "–", "—", "…", "°", "№"]
        case .symbols:        return ["%", "=", "π", "√", "^", "²", "°", "×", "÷", "±", "≈"]
        case .finance:        return ["$", "€", "£", "¥", "₹", "¢", "%", "‰", "(", ")"]
        case .programmer:     return ["0x", "0b", "&", "|", "^", "<<", ">>", "!=", "==", "{", "}"]
        default:              return []
        }
    }
}

// MARK: - Date/Time pack tokens (pure, unit-tested)

/// Pure value provider for the Date/Time pack. Each pack key displays a short label but carries a
/// wrapped action token (`keyToken(for:)`); the keyboard's tap handler unwraps it and inserts
/// `value(for:now:locale:)`. Returns `nil` for unknown tokens so callers can fall back gracefully.
enum DateTimeTokens {

    /// Ordered (token, short display label) pairs for the Date/Time pack row.
    static let ordered: [(token: String, label: String)] = [
        ("date", "Date"), ("time", "Time"), ("datetime", "D+T"),
        ("weekday", "Day"), ("month", "Mon"), ("day", "DD"),
        ("year", "YYYY"), ("iso", "ISO"), ("isodatetime", "ISO+"), ("unix", "Unix")
    ]

    /// Resolve a token to its inserted string for the given instant and locale.
    static func value(for token: String, now: Date, locale: Locale) -> String? {
        switch token {
        case "date":        return styled(now, date: .medium, time: .none, locale: locale)
        case "time":        return styled(now, date: .none, time: .short, locale: locale)
        case "datetime":    return styled(now, date: .medium, time: .short, locale: locale)
        case "weekday":     return patterned(now, "EEEE", locale: locale)
        case "month":       return patterned(now, "MMMM", locale: locale)
        case "day":         return patterned(now, "d", locale: locale)
        case "year":        return patterned(now, "yyyy", locale: locale)
        case "iso":         return isoDate(now)
        case "isodatetime": return isoDateTime(now)
        case "unix":        return String(Int(now.timeIntervalSince1970))
        default:            return nil
        }
    }

    // MARK: Key-token wrapping — keeps date/time keys distinct from slot/custom tokens.

    private static let keyPrefix = "{dt:"
    static func keyToken(for token: String) -> String { keyPrefix + token + "}" }
    static func token(fromKey key: String) -> String? {
        guard key.hasPrefix(keyPrefix), key.hasSuffix("}") else { return nil }
        return String(key.dropFirst(keyPrefix.count).dropLast())
    }

    // MARK: Formatting helpers

    private static func styled(_ date: Date, date dateStyle: DateFormatter.Style, time timeStyle: DateFormatter.Style, locale: Locale) -> String {
        let f = DateFormatter(); f.locale = locale; f.dateStyle = dateStyle; f.timeStyle = timeStyle
        return f.string(from: date)
    }
    private static func patterned(_ date: Date, _ pattern: String, locale: Locale) -> String {
        let f = DateFormatter(); f.locale = locale; f.dateFormat = pattern
        return f.string(from: date)
    }
    private static func isoDate(_ date: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
    private static func isoDateTime(_ date: Date) -> String {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime]
        return f.string(from: date)
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

// MARK: - iCloud sync (Pro) — app group ↔ NSUbiquitousKeyValueStore mirror

/// Mirrors the user's portable data between the shared app group and iCloud key-value storage.
/// Whole-value, last-writer-wins per key (KVS has a ~1 MB budget; our data is well under it).
/// Runs **app-side only** — the keyboard extension has no iCloud entitlement and picks up pulled
/// changes through the app group + `SettingsSync`. Clipboard history is intentionally excluded: it
/// lives in the keychain for security (see `ClipboardHistoryManager`) and must not be copied into
/// plaintext KVS — syncing it would require iCloud Keychain instead (see deferred log).
enum CloudSync {
    /// App-group keys mirrored to iCloud: snippets, custom pack/slots, the custom keyboard +
    /// handedness, and the headline appearance settings.
    static let syncedKeys: [String] = [
        Constants.snippets.rawValue,
        Constants.customPackKeys.rawValue,
        Constants.customKeySlots.rawValue,
        Constants.selectedKeyboardTheme.rawValue,
        Constants.heightPreset.rawValue,
        Constants.customKeyboardConfig.rawValue,
        Constants.handedness.rawValue
    ]

    /// Pure gate: sync runs only when the user opted in AND they're Pro AND the capability exists.
    static func isEnabled(userEnabled: Bool, proEntitled: Bool, capabilityAvailable: Bool) -> Bool {
        return userEnabled && proEntitled && capabilityAvailable
    }

    /// True once the app target declares the iCloud KVS entitlement. Without provisioning the KVS
    /// calls are harmless no-ops, so this stays true even before the capability is fully set up.
    static var capabilityAvailable: Bool { true }

    static var isActive: Bool {
        isEnabled(userEnabled: UserPrefs.iCloudSyncEnabled,
                  proEntitled: Monetization.isProEntitled,
                  capabilityAvailable: capabilityAvailable)
    }

    private static let cloud = NSUbiquitousKeyValueStore.default
    private static let group = UserDefaults.group

    /// Push local values up to iCloud. Call when the app backgrounds.
    static func push() {
        guard isActive else { return }
        for key in syncedKeys where group.object(forKey: key) != nil {
            cloud.set(group.object(forKey: key), forKey: key)
        }
        cloud.synchronize()
    }

    /// Pull iCloud values into the app group — only keys that exist in the cloud, so a nil cloud
    /// value never wipes local data — then notify the keyboard. Call on foreground + external change.
    static func pull() {
        guard isActive else { return }
        var changed = false
        for key in syncedKeys {
            if let value = cloud.object(forKey: key) {
                group.set(value, forKey: key)
                changed = true
            }
        }
        if changed { SettingsSync.post() }
    }

    /// Begin observing external iCloud changes and reconcile once. Safe to call when sync turns on.
    static func start() {
        guard isActive else { return }
        NotificationCenter.default.addObserver(forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                                               object: cloud, queue: .main) { _ in pull() }
        cloud.synchronize()
        pull()
    }
}

// MARK: - Snippets Manager

struct Snippet: Codable, Equatable {
    var title: String
    var text: String
}

extension Snippet {
    /// Dynamic tokens, expanded at insert time (not at save time), so a snippet like
    /// "Invoice {date}" always inserts today's date. Formatting is locale-aware.
    static let dateToken = "{date}"
    static let timeToken = "{time}"

    /// Snippet tokens mapped to the shared `DateTimeTokens` engine (DRY with the Date & Time pack),
    /// in replacement order. A `nil` `dt` token resolves to the latest clipboard text instead.
    static let tokenMap: [(token: String, dt: String?)] = [
        (dateToken, "date"), (timeToken, "time"), ("{datetime}", "datetime"),
        ("{day}", "weekday"), ("{month}", "month"), ("{year}", "year"),
        ("{iso}", "iso"), ("{unix}", "unix"), ("{clipboard}", nil)
    ]

    /// The snippet's text with dynamic tokens expanded. `now` is injectable for tests.
    func expandedText(now: Date = Date()) -> String {
        return Snippet.expand(text, now: now)
    }

    /// Expand every supported token. Date/time tokens reuse `DateTimeTokens.value` so formatting
    /// matches the Date & Time pack; `{clipboard}` resolves via the injectable `clipboard` closure
    /// (defaulting to the most-recent clipboard-history entry). Token-free text is returned unchanged.
    static func expand(_ text: String, now: Date = Date(), locale: Locale = .current,
                       clipboard: () -> String? = { ClipboardHistoryManager.shared.history.first }) -> String {
        var out = text
        for (token, dt) in tokenMap where out.contains(token) {
            let value = dt.flatMap { DateTimeTokens.value(for: $0, now: now, locale: locale) } ?? clipboard() ?? ""
            out = out.replacingOccurrences(of: token, with: value)
        }
        return out
    }
}

/// Ordered token catalog rendered as composer chips (Task 3.3). Must stay in sync with
/// `Snippet.tokenMap` (enforced by `test_catalogMatchesEngineTokens`).
enum SnippetTokens {
    static let all: [(token: String, label: String)] = [
        ("{date}", NSLocalizedString("Date", comment: "Snippet composer chip: inserts the current date")),
        ("{time}", NSLocalizedString("Time", comment: "Snippet composer chip: inserts the current time")),
        ("{datetime}", NSLocalizedString("Date+Time", comment: "Snippet composer chip: inserts the current date and time")),
        ("{day}", NSLocalizedString("Day", comment: "Snippet composer chip: inserts the current weekday")),
        ("{month}", NSLocalizedString("Month", comment: "Snippet composer chip: inserts the current month")),
        ("{year}", NSLocalizedString("Year", comment: "Snippet composer chip: inserts the current year")),
        ("{iso}", NSLocalizedString("ISO", comment: "Snippet composer chip: inserts an ISO-8601 timestamp")),
        ("{unix}", NSLocalizedString("Unix", comment: "Snippet composer chip: inserts a Unix epoch timestamp")),
        ("{clipboard}", NSLocalizedString("Clipboard", comment: "Snippet composer chip: inserts the latest clipboard text"))
    ]
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
            writeLocal(Array(newValue.prefix(maxItems)))
        }
    }

    private func writeLocal(_ items: [Snippet]) {
        let data = try? JSONEncoder().encode(items)
        userDefaults.set(data, forKey: key)
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
    /// Falls back to the `DateTimeTokens` wrapped-key vocabulary (`{dt:date}`/`{dt:time}`/…) so a
    /// Custom Keyboard slot holding a date/time token shows its short pack label ("Date"/"Time"/…)
    /// instead of the raw wrapped token — the same rule the Date & Time pack keys already use.
    static func displayName(for token: String) -> String {
        switch token {
        case spaceToken: return NSLocalizedString("Space", comment: "")
        case tabToken: return NSLocalizedString("Tab", comment: "Name of the tab key")
        case cursorLeftToken: return "←"
        case cursorRightToken: return "→"
        case dismissToken: return NSLocalizedString("Hide", comment: "Label for the key that dismisses the keyboard")
        default:
            if let dtToken = DateTimeTokens.token(fromKey: token),
               let label = DateTimeTokens.ordered.first(where: { $0.token == dtToken })?.label {
                return label
            }
            return token
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
        return [.black, .deepPurple, .indigo, .teal, .deepOrange, .glass, .glassDark]
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
            // Empty by default so the *localized* bundled pitch wins on the paywall in every
            // locale. Publish a per-locale Remote Config `price_copy` to override intentionally.
            "price_copy": "" as NSObject,
            "default_theme": KeyboardTheme.white.rawValue as NSObject,
            "default_pack": KeyboardType.default.rawValue as NSObject,
            "packs_enabled": "math,math2,finance,symbols,programmer,datetime,units,cooking" as NSObject,
            "tax_default_percent": 15 as NSNumber,
            "first_run_upsell_enabled": true as NSObject,
            "upsell_after_sessions": 8 as NSNumber,
            "early_bird_window_hours": 72 as NSNumber,
            // Production kill switch for the Custom Keyboard editor's drag-reorder UI (see
            // FeatureFlags.customKeyboardDragReorderEnabled / dragReorderActive). Defaults true so
            // behavior is unchanged until this is explicitly flipped off in the Firebase console.
            "custom_keyboard_drag_reorder_enabled": true as NSObject,
            // Production kill switch for Live Math Preview (see LiveMathPreview / the mirroring in
            // fetchAndActivate below). Defaults true so behavior is unchanged until this is
            // explicitly flipped off in the Firebase console.
            "live_math_preview_enabled": true as NSObject,
            // Production kill switch for the key-press micro-interaction (see
            // FeatureFlags.keyPressAnimation / the mirroring in fetchAndActivate below). Defaults
            // true so behavior is unchanged until this is explicitly flipped off in the console.
            "key_press_animation_enabled": true as NSObject,
            // Production kill switch for the App Intents (Siri/Shortcuts/Spotlight) integration —
            // see FeatureFlags.appIntentsEnabled / appIntentsActive. Defaults true so behavior is
            // unchanged until this is explicitly flipped off in the Firebase console.
            "app_intents_enabled": true as NSObject,
            // Production kill switch for the interactive first-run onboarding (WOW/ENABLE/TRY IT —
            // see OnboardingFlow.shouldShow). Defaults true; flipping it off in the Firebase console
            // reverts every fresh install straight to the legacy Instructions push.
            "onboarding_enabled": true as NSObject
        ]
        rc.setDefaults(defaults)
    }

    func fetchAndActivate() {
        rc.fetchAndActivate(completionHandler: { _, _ in
            RemoteConfigManager.shared.mirrorLiveMathPreviewKillSwitch()
            RemoteConfigManager.shared.mirrorKeyPressAnimationKillSwitch()
        })
    }

    /// Mirrors the Live Math Preview RC kill switch into the shared app group. The keyboard
    /// extension has no Firebase Remote Config of its own (it isn't linked there — see
    /// `Analytics`), so this is the only way it can ever see the value; `LiveMathPreview.isEnabled`
    /// reads the mirrored flag directly. Only posts `SettingsSync` when the value actually changed,
    /// so a live keyboard extension doesn't get spurious reload churn on every foreground fetch.
    private func mirrorLiveMathPreviewKillSwitch() {
        let enabled = liveMathPreviewEnabled
        guard LiveMathPreview.remoteEnabled != enabled else { return }
        LiveMathPreview.remoteEnabled = enabled
        SettingsSync.post()
    }

    /// Mirrors the key-press-animation RC kill switch into the shared app group, exactly like
    /// `mirrorLiveMathPreviewKillSwitch` above — the Keyboard extension (which actually renders the
    /// animation) has no Firebase Remote Config of its own. Only posts `SettingsSync` when the
    /// value actually changed, so a live keyboard extension doesn't get spurious reload churn.
    private func mirrorKeyPressAnimationKillSwitch() {
        let enabled = keyPressAnimationEnabled
        guard FeatureFlags.keyPressAnimationRemoteEnabled != enabled else { return }
        FeatureFlags.keyPressAnimationRemoteEnabled = enabled
        SettingsSync.post()
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
    /// Master switch for the new-buyer proactive first-run paywall (`NewBuyerUpsell`).
    var firstRunUpsellEnabled: Bool { rc["first_run_upsell_enabled"].boolValue }
    /// Sessions before the session-milestone upsell fires (`SessionMilestone`). Falls back to 8 if
    /// RC hasn't fetched/returns an invalid value.
    var upsellAfterSessions: Int {
        let v = Int(truncating: rc["upsell_after_sessions"].numberValue)
        return v > 0 ? v : 8
    }
    /// Early-bird discount window length in hours. Falls back to the historical 72h.
    var earlyBirdWindowHours: Double {
        let v = rc["early_bird_window_hours"].numberValue.doubleValue
        return v > 0 ? v : 72
    }
    /// Production kill switch for the Custom Keyboard editor's drag-reorder UI (app-side only —
    /// the editor is a NumPad-app-only screen, so real Remote Config is always available here).
    /// Combine with the local `FeatureFlags` value via `FeatureFlags.dragReorderActive(...)`.
    var customKeyboardDragReorderEnabled: Bool { rc["custom_keyboard_drag_reorder_enabled"].boolValue }
    /// Production kill switch for Live Math Preview. Read app-side only — the keyboard extension
    /// consumes the mirrored `LiveMathPreview.remoteEnabled` value instead (see
    /// `mirrorLiveMathPreviewKillSwitch`), since it has no Remote Config of its own.
    var liveMathPreviewEnabled: Bool { rc["live_math_preview_enabled"].boolValue }
    /// Production kill switch for the key-press micro-interaction. Read app-side only — the
    /// keyboard extension consumes the mirrored `FeatureFlags.keyPressAnimationRemoteEnabled`
    /// value instead (see `mirrorKeyPressAnimationKillSwitch`), since it has no Remote Config of
    /// its own.
    var keyPressAnimationEnabled: Bool { rc["key_press_animation_enabled"].boolValue }
    /// Production kill switch for the App Intents (Siri/Shortcuts/Spotlight) integration — app-side
    /// only, like `customKeyboardDragReorderEnabled` above (App Intents never run in the Keyboard
    /// extension, so real Remote Config is always available here; no mirroring needed).
    var appIntentsEnabled: Bool { rc["app_intents_enabled"].boolValue }
    /// Production kill switch for the interactive first-run onboarding — app-side only, like
    /// `appIntentsEnabled` above (onboarding never runs in the Keyboard extension).
    var onboardingEnabled: Bool { rc["onboarding_enabled"].boolValue }
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
    var firstRunUpsellEnabled: Bool { true }
    var upsellAfterSessions: Int { 8 }
    var earlyBirdWindowHours: Double { 72 }
    // Not consumed in the extension (the drag-reorder editor is app-side only), but stubbed for
    // symmetry with the real implementation above.
    var customKeyboardDragReorderEnabled: Bool { true }
    // Not consumed in the extension (it reads the mirrored LiveMathPreview.remoteEnabled instead),
    // but stubbed for symmetry with the real implementation above.
    var liveMathPreviewEnabled: Bool { true }
    // Not consumed in the extension (it reads the mirrored
    // FeatureFlags.keyPressAnimationRemoteEnabled instead), but stubbed for symmetry.
    var keyPressAnimationEnabled: Bool { true }
    // Not consumed in the extension (App Intents are app-side only), but stubbed for symmetry.
    var appIntentsEnabled: Bool { true }
    // Not consumed in the extension (onboarding is app-side only), but stubbed for symmetry.
    var onboardingEnabled: Bool { true }
}
#endif

// MARK: - Clipboard History Manager

/// One stored clipboard entry. The capture timestamp drives TTL expiry so we never retain
/// copied content (which may include passwords, 2FA codes, card numbers) indefinitely —
/// unless the user explicitly pins an entry, which opts it out of expiry.
struct ClipboardEntry: Codable, Equatable {
    let text: String
    let date: Date
    var pinned: Bool

    init(text: String, date: Date, pinned: Bool = false) {
        self.text = text
        self.date = date
        self.pinned = pinned
    }

    // `pinned` was added after entries were first persisted; default missing keys to false.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        text = try container.decode(String.self, forKey: .text)
        date = try container.decode(Date.self, forKey: .date)
        pinned = try container.decodeIfPresent(Bool.self, forKey: .pinned) ?? false
    }
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

    /// Pin-aware visibility and ordering, pure so it can be unit-tested: pinned entries are
    /// exempt from TTL expiry and always listed first; each group stays most-recent-first.
    /// All index-based mutations operate on this same ordering so visible indices line up.
    static func visible(_ entries: [ClipboardEntry], cutoff: Date) -> [ClipboardEntry] {
        let kept = entries.filter { $0.pinned || $0.date >= cutoff }
        return kept.filter { $0.pinned } + kept.filter { !$0.pinned }
    }

    private var visibleEntries: [ClipboardEntry] {
        return Self.visible(entries, cutoff: Date().addingTimeInterval(-timeToLive))
    }

    /// Non-expired history (pinned first, then most recent). Empty if the user disabled the feature.
    var history: [String] {
        guard UserPrefs.clipboardHistoryEnabled else { return [] }
        return visibleEntries.map { $0.text }
    }

    /// Like `history`, but with the pin state for UI affordances.
    var items: [(text: String, isPinned: Bool)] {
        guard UserPrefs.clipboardHistoryEnabled else { return [] }
        return visibleEntries.map { ($0.text, $0.pinned) }
    }

    func add(_ item: String) {
        guard UserPrefs.clipboardHistoryEnabled else { return }
        lock.lock(); defer { lock.unlock() }
        let current = visibleEntries
        // Re-copying a pinned entry keeps it pinned; otherwise the new capture goes to the
        // top of the unpinned group.
        let wasPinned = current.first { $0.text == item }?.pinned ?? false
        var kept = current.filter { $0.text != item }
        let new = ClipboardEntry(text: item, date: Date(), pinned: wasPinned)
        if wasPinned {
            kept.insert(new, at: 0)
        } else {
            let pinnedCount = kept.prefix { $0.pinned }.count
            kept.insert(new, at: pinnedCount)
        }
        entries = kept
    }

    func clear() {
        lock.lock(); defer { lock.unlock() }
        KeychainStore.set(nil, service: service, account: account)
    }

    func remove(at index: Int) {
        lock.lock(); defer { lock.unlock() }
        var items = visibleEntries
        guard items.indices.contains(index) else { return }
        items.remove(at: index)
        entries = items
    }

    /// Toggle the pin on the entry at the given *visible* index. Pinning exempts the entry from
    /// TTL expiry (an explicit user choice to retain it); unpinning restarts its expiry clock.
    func togglePin(at index: Int) {
        lock.lock(); defer { lock.unlock() }
        var items = visibleEntries
        guard items.indices.contains(index) else { return }
        let entry = items.remove(at: index)
        let toggled = ClipboardEntry(text: entry.text, date: entry.pinned ? Date() : entry.date, pinned: !entry.pinned)
        let pinnedCount = items.prefix { $0.pinned }.count
        items.insert(toggled, at: toggled.pinned ? 0 : pinnedCount)
        entries = Self.visible(items, cutoff: Date().addingTimeInterval(-timeToLive))
    }

    #if DEBUG
    /// Replaces history with `texts` (first item pinned). Used only by the iPad App Store
    /// screenshot harness so the overlay has realistic recent-number rows.
    func debugReplaceHistory(_ texts: [String]) {
        lock.lock(); defer { lock.unlock() }
        entries = texts.enumerated().map { index, text in
            ClipboardEntry(text: text, date: Date(), pinned: index == 0)
        }
    }
    #endif
}
