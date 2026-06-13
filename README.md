# NumPad – Custom Numeric Keyboard
NumPad is a customizable numeric keyboard extension and companion app for iOS. It offers math/finance/programmer/symbol packs, themes, snippets, clipboard history, and helpful overlays like TAX/TIP. A real StoreKit 2 store sells NumPad Pro (lifetime, unlocks everything) and a standalone Finance Pack; the paywall is **ON by default** and premium packs/themes are gated until purchased (users from before 1.7.0 are grandfathered).

![Swift](https://img.shields.io/badge/Swift-5-orange.svg?style=flat)
![Platform](https://img.shields.io/badge/Platform-iOS%2015%2B-blue.svg?style=flat)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg?style=flat-square)](http://makeapullrequest.com)

## New Features & Improvements (2025)

- Keyboard overlays
  - Clipboard history: long‑press "0" to open; tap to insert
  - Snippets panel: long‑press "." to open; tap to insert
  - TAX/TIP helper: long‑press "%" to compute and insert result
- Packs
  - Math + Math2 toggle
  - Finance row (currencies, +/-)
  - Symbols row (@ # & * = + - / \ ~)
  - Programmer row (0x, bitwise ops)
- Themes
  - Premium theme lock indicators; tapping a locked theme deep‑links to the Store
- App screens
  - Store (Preview): toggles for Paywall, Pro entitlement; Haptics and Key Click Sound
  - Snippets manager: add/delete snippets
  - Keyboard Packs selector: None, Math, Finance, Symbols, Programmer
  - Privacy & Full Access explainer
  - Home: "Try the NumPad keyboard here" demo field
- Monetization (StoreKit 2)
  - Real purchases: NumPad Pro (lifetime) and Finance Pack, with Restore Purchases
  - Paywall ON by default; pre‑1.7.0 users grandfathered
  - Lock chips on premium keys with deep‑link to Store
- Remote Config scaffolding
  - Price copy, default theme, default pack; fetched at launch and applied once
- Quality improvements
  - Optional haptics on key press; key click respects user toggle
  - Analytics events already integrated (Firebase)

## Developer Toggles

All toggles are centralized and persisted in the shared app group so both the app and keyboard can read them.

- Paywall and entitlement
  - `Monetization.paywallEnabled` (default `true`)
  - `Monetization.isProEntitled` is **computed** from real purchases + grandfathering (read‑only)
  - Gating helpers: `Monetization.isLocked(pack:)`, `Monetization.isLocked(theme:)`, `Monetization.isKeyLocked(pack:row:)` — all return `false` when the paywall is off or the user is entitled
  - StoreKit 2 purchase/restore lives in `StoreManager` (app target); a DEBUG‑only Store section simulates paywall/entitlement states
- Haptics and sound
  - `UserPrefs.hapticsEnabled` (default `true`)
  - `UserPrefs.soundEnabled` (default `true`)
- Remote Config
  - `RemoteConfigManager.start()` initializes and fetches RC
  - First‑run application of defaults in `Base/ViewController` under the `rcApplied` flag

You can also quickly switch features in the Store (Preview) screen inside the app.

## Keyboard Gestures

- Long‑press "0": Clipboard History
- Long‑press ".": Snippets
- Long‑press "%": TAX/TIP helper
- Long‑press "=": Unit Conversion _(when the Conversion Overlay flag is on)_
- Long‑press the return key: Recent Results _(when the Last‑Result Tape flag is on)_
- Drag across the space bar: move the caret _(when Cursor Controls is on)_

## Experimental Features (Beta flags)

Post‑1.7.0 capabilities ship **off by default**. Their toggles appear in a "Feature Flags (Beta)"
section in the Store screen, visible only in **DEBUG and TestFlight** builds (never the App Store).
All flags live in the shared app group (`FeatureFlags`), so the keyboard reacts immediately.

| Flag | What it does |
|------|--------------|
| Inline Calculator | Tap `=` to evaluate the expression before the cursor |
| Locale‑Aware Separators | The decimal key inserts your region's separator |
| Cursor Controls | Drag the space bar to move the caret |
| Conversion Overlay | Long‑press `=` for offline length/mass/temperature conversion |
| Last‑Result Tape | Long‑press return for recent results; `+` in Snippets saves the latest |
| Save Snippet From Keyboard | A `+` button in the Snippets overlay saves the last result |
| iCloud Sync | Sync snippets across devices — **requires** the iCloud Key‑Value storage capability/entitlement to actually sync |
| Smart Pack Defaulting | Auto‑suggest an unlocked pack based on the field being edited |

## File Map (Key Additions)

- App
  - `NumPad/Controllers/StoreViewController.swift` – paywall/entitlement + haptics/sound toggles
  - `NumPad/Controllers/SnippetsViewController.swift` – manage snippets
  - `NumPad/Controllers/PacksViewController.swift` – select keyboard packs
  - `NumPad/Controllers/PrivacyViewController.swift` – Full Access info
  - `NumPad/Controllers/Base/ViewController.swift` – splash, onboarding, RC apply, deep-link routing, demo field
  - `NumPad/Libraries/SharedExtensions.swift` – feature flags, snippets, Remote Config, analytics
  - `NumPad/Libraries/Keyboard.swift` – keyboard types, themes
  - `NumPad/Info.plist` – `numpad://` URL scheme
- Keyboard
  - `Keyboard/KeyboardViewController.swift` – overlay presentation and deep-links
  - `Keyboard/Views/ClipboardHistoryView.swift` – clipboard overlay
  - `Keyboard/Views/SnippetsListView.swift` – snippets overlay
  - `Keyboard/Views/TaxTipView.swift` – TAX/TIP overlay
  - `Keyboard/Libraries/Item.swift` – renders pack rows
  - `Keyboard/Views/StackView.swift` – lock chip overlay logic
  - `Keyboard/Views/Button.swift` – haptics per key tap

## How to Toggle Features (programmatically)

```swift
Monetization.paywallEnabled = true  // gate premium content (default)
// Entitlement is derived from real purchases + grandfathering; it is not set directly.
// In DEBUG builds you can simulate it: Monetization.debugProOverride = true
UserPrefs.hapticsEnabled = true
UserPrefs.soundEnabled = true

// Experimental features ship OFF; toggles appear in the Store screen in DEBUG/TestFlight.
FeatureFlags.inlineCalculator = false
```

## Release Checklist (App Store)

- Set desired defaults via Remote Config (price copy, default theme/pack)
- Toggle paywall behavior as needed (leave OFF for testing builds)
- Verify URL scheme deep-link from keyboard (`numpad://store-preview`)
- Validate privacy copy in Privacy screen
- Run lint and smoke test: overlays, packs, themes, and Store (Preview)

## Firebase & Tooling

- Firebase Analytics/Crashlytics/Performance integrated
- Remote Config scaffolded; edit defaults in `RemoteConfigManager.configureDefaults()`
- Upload DSYMs when needed:
```
Pods/FirebaseCrashlytics/upload-symbols -gsp NumPad/GoogleService-Info.plist -p ios appDsyms.zip
```
