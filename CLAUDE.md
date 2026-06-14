# CLAUDE.md — NumPad Codebase Guide

## Project Overview

NumPad is an iOS custom numeric keyboard extension with a companion app. It provides a configurable numpad with swappable packs (Math, Finance, Symbols, Programmer, Tax/Tips), themes, snippets, clipboard history, and overlay helpers (TAX/TIP calculator). The project is written entirely in **Swift** and uses **UIKit** (no SwiftUI).

- **Minimum deployment target:** iOS 15.0
- **Dependency manager:** CocoaPods (static linkage)
- **Build system:** Xcode (`.xcworkspace` — always open the workspace, not the `.xcodeproj`)
- **Bundle identifier:** `com.morevoltage.NumPad`
- **URL scheme:** `numpad://` (used for deep-links from keyboard to app)

## Repository Structure

```
NumPad/                          # Root
├── NumPad/                      # Container app target
│   ├── AppDelegate.swift        # App entry point, Firebase init, theme config
│   ├── Controllers/
│   │   ├── Base/
│   │   │   ├── ViewController.swift       # Root VC: splash, onboarding, RC apply, deep-link routing
│   │   │   └── TableViewController.swift  # Base table VC with shared row styling
│   │   ├── HomeViewController.swift       # Main settings table (packs, themes, toggles)
│   │   ├── ThemeViewController.swift      # Theme picker
│   │   ├── PacksViewController.swift      # Keyboard pack selector
│   │   ├── SnippetsViewController.swift   # Snippets manager (add/delete)
│   │   ├── StoreViewController.swift      # StoreKit 2 store + behavior toggles + Feature Flags (Beta)
│   │   ├── PrivacyViewController.swift    # Full Access explainer
│   │   └── InstructionsViewController.swift # Keyboard enable guide
│   ├── Libraries/
│   │   ├── SharedExtensions.swift   # Shared between app & extension: feature flags, managers, analytics
│   │   ├── Keyboard.swift           # Keyboard config (type, theme, appearance enums)
│   │   ├── StoreManager.swift       # StoreKit 2 purchases (app target only)
│   │   ├── Extensions.swift         # App-only UIKit helpers, localized strings
│   │   ├── RaterExtensions.swift    # SwiftRater config
│   │   └── TinyConstraintsExtensions.swift
│   ├── ExternalLibraries/          # Vendored navigation controller code
│   ├── Views/                      # App-side table cells, theme cells, preview
│   ├── Base.lproj/                 # Main.storyboard, LaunchScreen.storyboard
│   ├── Assets.xcassets/            # App images (PDF vector assets)
│   ├── Colors.xcassets/            # Named colors (primary)
│   ├── Info.plist                  # App config, URL scheme
│   ├── NumPad.entitlements         # App group: group.morevoltage.numpad.container
│   ├── GoogleService-Info.plist    # Firebase config
│   └── Settings.bundle/           # Settings.app entries
├── Keyboard/                       # Keyboard extension target
│   ├── KeyboardViewController.swift # Main extension VC: key handling, overlays, default height
│   ├── Libraries/
│   │   ├── Item.swift               # Key layout definitions per pack
│   │   └── Extensions.swift         # Extension-side helpers
│   ├── Views/
│   │   ├── StackView.swift          # Keyboard grid layout (UIStackView-based)
│   │   ├── Cell.swift               # Individual key cell
│   │   ├── Button.swift             # Custom button with haptics + continuous press
│   │   ├── InputView.swift          # Input view styling
│   │   ├── ClipboardHistoryView.swift # Clipboard overlay (long-press "0")
│   │   ├── SnippetsListView.swift   # Snippets overlay (long-press ".")
│   │   └── TaxTipView.swift         # TAX/TIP overlay (long-press "%")
│   ├── Info.plist                   # Extension config (keyboard-service)
│   ├── Keyboard.entitlements        # App group: group.morevoltage.numpad.container
│   └── GoogleService-Info.plist
├── NumPad.xcodeproj/
├── NumPad.xcworkspace/              # <-- Always use this to open the project
├── Podfile                          # CocoaPods dependency config
├── Podfile.lock
├── Bladefile                        # Icon generation config (blade tool)
├── fastlane/
│   ├── Fastfile                     # Beta distribution lane
│   └── README.md
├── ci_scripts/
│   └── ci_post_clone.sh             # Xcode Cloud: installs CocoaPods
├── icons/                           # Source icon assets
├── .gitignore
└── README.md
```

## Architecture

### Pattern: MVC (Model-View-Controller)

The app uses UIKit's standard MVC pattern:
- **Controllers** — `UITableViewController` subclasses for settings screens; `UIInputViewController` for the keyboard extension
- **Views** — Custom `UIView`/`UIButton` subclasses for keyboard cells, overlays
- **Models** — Structs and enums (`Item`, `Snippet`, `KeyboardType`, `KeyboardTheme`) in Libraries/

### Two Targets

| Target | Type | Bundle ID suffix | Purpose |
|--------|------|-------------------|---------|
| `NumPad` | App | `.NumPad` | Container app with settings, theme picker, store preview |
| `Keyboard` | App Extension | `.NumPad.Keyboard` | Custom keyboard extension (keyboard-service) |

Both share an **App Group** (`group.morevoltage.numpad.container`) for cross-process data:
- `UserDefaults.group` — all shared preferences and feature flags
- **Darwin notifications** (`SettingsSync`) — real-time cross-process messaging

### Shared Code

`SharedExtensions.swift` is compiled into **both** targets. It contains:
- `UserDefaults.group` — shared user defaults
- `@UserDefault` property wrapper — typed defaults access
- `Constants` enum — all UserDefaults keys
- `Analytics` — Firebase wrapper
- `Monetization` — paywall flag + StoreKit 2 purchase/grandfathering state and the gating map
- `UserPrefs` — haptics, sound, repurpose-next-key, clipboard-history toggles
- `FeatureFlags` — experimental feature toggles (off by default; DEBUG/TestFlight UI only)
- `SnippetsManager` — snippets CRUD (singleton)
- `ClipboardHistoryManager` — clipboard history (singleton)
- `RemoteConfigManager` — Firebase Remote Config (with `#if canImport` fallback stub for Keyboard target)
- `SettingsSync` — Darwin notification wrapper

`StoreManager.swift` (app target only) performs the actual StoreKit 2 purchases/restore and writes the resulting entitlement flags into `Monetization` for the keyboard to read.

`Keyboard.swift` is also shared and contains `Keyboard`, `KeyboardType`, and `KeyboardTheme` definitions.

## Key Conventions

### Settings & Feature Flags

All user settings use the `@UserDefault` property wrapper backed by the shared app group:

```swift
@UserDefault(key: Constants.someKey.rawValue, defaultValue: false, userDefaults: .group)
static var someFlag: Bool
```

Constants are defined in the `Constants` enum (raw string values). Always add new keys there.

### Cross-Process Communication

When the app changes a setting that the keyboard needs to pick up immediately:
1. Write to `UserDefaults.group`
2. Call `SettingsSync.post()` to notify the keyboard extension via Darwin notifications

### Monetization (StoreKit 2)

As of 1.7.0 the app uses **real StoreKit 2** purchases. The paywall is **ON by default**
(`Monetization.paywallEnabled = true`). Two non-consumables are sold: `numpad.pro.lifetime`
(unlocks all packs + premium themes) and `numpad.pack.finance` (the finance pack only).

- `StoreManager` (app target) runs purchase/restore and listens to `Transaction.updates`, then
  mirrors entitlements into the shared `Monetization` flags (`isProPurchased`,
  `isFinancePackPurchased`, `isGrandfathered`). The keyboard extension has no StoreKit — it only
  reads those flags.
- Users whose original purchase predates 1.7.0 are **grandfathered** (everything stays free).
- Gating helpers: `Monetization.isLocked(pack:)`, `Monetization.isLocked(theme:)`, and
  `Monetization.isKeyLocked(pack:row:)` (the single source of truth shared by the lock-chip overlay
  and the tap handler). All return `false` when the paywall is off or the user is entitled.
- A DEBUG-only "Debug" section in the Store screen simulates paywall/entitlement states.

### Keyboard Packs

Packs are defined in `KeyboardType` enum (`Keyboard.swift`) and their key layouts in `Item.swift`:
- `.default` — no extra row
- `.math` / `.math2` — math operators (toggleable)
- `.finance` — currency symbols
- `.symbols` — common symbols
- `.programmer` — bitwise ops, hex prefix
- `.custom` — user-built pack row (`CustomPackManager`, edited in the app's Custom Keys screen)

`.tax` is **not** a selectable pack — Tax/Tip is provided by the long-press "%" overlay (`TaxTipView`). The `.tax` enum case is retained for backward compatibility only.

The three right-side keys (comma / period / space by default) are remappable slots (`CustomKeys`);
slot tokens can also be cursor arrows, Tab, or a hide-keyboard key.

### Keyboard Height

`KeyboardHeightPreset` (Small 260 / Default 300 / Tall 340) sets the pre-clamp base height on
iPhone; the clamp (min 220 portrait / 160 landscape, max 50% of container) always applies. iPad
uses pure system sizing. Picker screen: `KeyboardHeightViewController` (Home → Keyboard Height).

### Keyboard Overlays

Long-press gestures on specific keys trigger overlay views:
- `"0"` → `ClipboardHistoryView` (clipboard history; swipe to pin/delete, pinned entries skip the 1-hour TTL)
- `"."` → `SnippetsListView` (user snippets; `{date}`/`{time}` tokens expand at insert time)
- `"%"` → `TaxTipView` (two-step tax + tip calculator; tip computed on the pre-tax amount via `TaxTipMath`)
- Next key (repurposed mode) → `PackPickerView` (jump directly to a pack)
- `"="` → `ConversionView`, return key → `ResultTapeView` (both feature-flagged)

Overlays use a delegate pattern (e.g., `ClipboardHistoryViewDelegate`) to communicate results back to `KeyboardViewController`.

On **iPad ≥700pt wide**, overlays present as a 360pt trailing side panel (`installOverlayBeside`)
instead of a top band, keys are pointer-hover enabled, and clipboard/snippet rows support drag &
drop into the host app.

### Themes

`KeyboardTheme` is a `CaseIterable` enum with 17 color themes. Each has a `color` property mapping to `UIColor.Custom` static colors. Premium themes are defined in `KeyboardTheme.premiumThemes` and only visually gated when the paywall is enabled.

### Storyboard vs Programmatic UI

- App settings screens that existed early (Instructions, Theme, Home) use **Main.storyboard** and are instantiated via `UIViewController.instantiate()`
- Newer screens (Store, Packs, Snippets, Privacy, Custom Keys, Keyboard Height) are created **programmatically**
- The keyboard extension is fully **programmatic** (no storyboard)

### Analytics

Firebase Analytics is integrated. Log events via:
```swift
Analytics.logEvent(name: "event_name", attributes: ["key": value])
```

Firebase is initialized lazily: `Analytics.start` (a static `let` closure).

The **keyboard extension never logs analytics** (no keystroke tracking; Firebase is not even
linked there). Purchase-funnel attribution works via the deep link instead: locked keys open
`numpad://store-preview?source=key_lock|pack_picker`, and the **app** logs `store_viewed` with
that source when the Store screen appears (see `StoreViewController.source`).

### Localization

User-facing strings use `NSLocalizedString()`. Static localized strings are defined as `String` extensions in `Extensions.swift`.

## Dependencies (CocoaPods)

### Shared (both targets)
- **FirebaseAnalytics** — event tracking
- **GoogleUtilities** — Firebase dependency
- **DynamicColor** — color manipulation
- **TinyConstraints** — Auto Layout helpers

### Keyboard only
- **SwiftyTimer** — `Timer.every()` convenience for continuous-press buttons

### App only
- **FirebaseCrashlytics** — crash reporting
- **FirebasePerformance** — performance monitoring
- **SwiftRater** — App Store rating prompt
- **RevealingSplashView** — animated splash screen
- **TextAttributes** — `NSAttributedString` builder

Firebase Remote Config is pulled in transitively via FirebasePerformance.

## Build & Development

### Prerequisites
- Xcode (latest stable)
- CocoaPods (`brew install cocoapods`)

### Setup
```bash
pod install
open NumPad.xcworkspace
```

### CI (Xcode Cloud)
The `ci_scripts/ci_post_clone.sh` script runs `brew install cocoapods && pod install` after cloning.

### Fastlane
A `beta` lane exists for ad-hoc builds distributed via Crashlytics Beta:
```bash
fastlane beta
```

### Icon Generation
The `Bladefile` configures [Blade](https://github.com/jondot/blade) to generate app icon assets from `iTunesArtwork@2x.png`:
```bash
blade
```

## Common Tasks

### Adding a new keyboard pack
1. Add a case to `KeyboardType` enum in `Keyboard.swift`
2. Add it to `KeyboardType.packs` array
3. Define its key layout in `Item.pack(type:)` in `Keyboard/Libraries/Item.swift`
4. Optionally add it to `RemoteConfigManager.configureDefaults()` packs_enabled list

### Adding a new theme
1. Add a case to `KeyboardTheme` enum in `Keyboard.swift`
2. Add its color to `UIColor.Custom` in `SharedExtensions.swift`
3. Map it in `KeyboardTheme.color` computed property
4. Optionally add to `KeyboardTheme.premiumThemes` if it should be premium

### Adding a new settings toggle
1. Add a key to `Constants` enum in `SharedExtensions.swift`
2. Add a `@UserDefault` property in the appropriate struct (`UserPrefs`, `Monetization`, or `Keyboard`)
3. Add a UI row in the relevant view controller (typically `HomeViewController` or `StoreViewController`)
4. Call `SettingsSync.post()` after changes if the keyboard extension needs to react

### Adding a new overlay
1. Create a new `UIView` subclass in `Keyboard/Views/`
2. Define a delegate protocol for communicating results
3. Add a long-press gesture recognizer in `KeyboardViewController.reloadItems()`
4. Add show/dismiss methods following the pattern of `ClipboardHistoryView`

## Important Notes

- **Always open `NumPad.xcworkspace`**, not the `.xcodeproj` — CocoaPods generates the workspace
- **`SharedExtensions.swift` and `Keyboard.swift`** are compiled into both targets — be careful with `#if canImport()` guards for app-only frameworks
- The keyboard extension has **limited memory** (~50MB) — avoid heavy allocations
- **Full Access** (`RequestsOpenAccess` in Keyboard `Info.plist`) is required for clipboard access, haptics, and key click sounds (Firebase/analytics is intentionally **not** linked into the extension)
- The `Pods/` directory is gitignored — run `pod install` after cloning
- The `numpad://` URL scheme enables deep-linking from the keyboard extension to the container app (e.g., `numpad://store-preview` opens the Store screen)
- Darwin notifications are the only reliable cross-process communication mechanism for keyboard extensions — do not rely on `NotificationCenter` for app-to-extension messaging
