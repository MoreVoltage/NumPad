# NumPad – Custom Numeric Keyboard
NumPad is a customizable numeric keyboard extension and companion app for iOS. It offers math/finance/programmer/symbol packs, themes, snippets, clipboard history, and helpful overlays like TAX/TIP. A Store (Preview) lets you toggle a paywall and simulated entitlement for testing. By default the paywall is OFF so everything is accessible during development.

[![Swift Version][swift-image]][swift-url]
[![Build Status][travis-image]][travis-url]
[![License][license-image]][license-url]
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![CocoaPods Compatible](https://img.shields.io/cocoapods/v/EZSwiftExtensions.svg)](https://img.shields.io/cocoapods/v/LFAlertController.svg)  
[![Platform](https://img.shields.io/cocoapods/p/LFAlertController.svg?style=flat)](http://cocoapods.org/pods/LFAlertController)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg?style=flat-square)](http://makeapullrequest.com)

One to two paragraph statement about your product and what it does.

![](header.png)

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
  - Premium theme lock indicators (only visual when paywall OFF)
- App screens
  - Store (Preview): toggles for Paywall, Pro entitlement; Haptics and Key Click Sound
  - Snippets manager: add/delete snippets
  - Keyboard Packs selector: None, Math, Finance, Symbols, Programmer
  - Privacy & Full Access explainer
  - Home: "Try the NumPad keyboard here" demo field
- Monetization scaffolding
  - Paywall flag and Pro entitlement (via `Monetization`), default paywall OFF
  - Lock chips on premium keys with deep‑link to Store
- Remote Config scaffolding
  - Price copy, default theme, default pack; fetched at launch and applied once
- Quality improvements
  - Optional haptics on key press; key click respects user toggle
  - Analytics events already integrated (Firebase)

## Developer Toggles

All toggles are centralized and persisted in the shared app group so both the app and keyboard can read them.

- Paywall and entitlement
  - `Monetization.paywallEnabled` (default `false`)
  - `Monetization.isProEntitled` (default `true`)
  - Helper: `Monetization.isFeatureLocked()` returns `true` only when paywall is ON and entitlement is OFF
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
Monetization.paywallEnabled = false // keep everything free (default)
Monetization.isProEntitled = true   // simulate Pro (default)
UserPrefs.hapticsEnabled = true
UserPrefs.soundEnabled = true
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
