//
//  NumPadShortcuts.swift
//  NumPad
//
//  App Intents support (App target only — the Keyboard extension is untouched).
//

import AppIntents

/// Registers NumPad's App Intents as zero-setup App Shortcuts — the system surfaces these phrases
/// in Siri and Spotlight the moment the app is installed, no user configuration needed.
///
/// Monetization note: these three intents are fully functional regardless of pack ownership or
/// Pro status. Unlike the keyboard, where locked packs/keys are the paid product, a Siri/Shortcuts
/// conversion or calculation is marketing surface area — showing up in Spotlight and Siri sells
/// the app. Gating dialogs behind entitlements here would only make the free trial of NumPad's
/// value proposition worse, not protect revenue.
///
/// Note: `AppShortcutPhrase`'s string interpolation (`\(.applicationName)`) is a compile-time DSL,
/// not a runtime `LocalizedStringResource` — it can't be wrapped in `NSLocalizedString()` without
/// losing the special app-name/parameter interpolation, so these phrases are literal Swift source
/// rather than going through the usual localization pipeline. Localizing them per-locale would
/// need Apple's dedicated AppShortcuts string-table mechanism as a follow-up.
///
/// Localization note (shortTitle): like the phrases above, `shortTitle` MUST be a literal
/// `LocalizedStringResource` — see the note atop `TipIntent.swift` for why
/// (`appintentsmetadataprocessor` statically parses this file at build time and can't evaluate a
/// call like `NSLocalizedString(...)`).
struct NumPadShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ConvertUnitsIntent(),
            phrases: [
                "Convert with \(.applicationName)",
                "Convert units with \(.applicationName)"
            ],
            shortTitle: LocalizedStringResource("Convert Units", comment: "App Shortcut tile title"),
            systemImageName: "arrow.left.arrow.right"
        )
        AppShortcut(
            intent: CalculateIntent(),
            phrases: [
                "Calculate with \(.applicationName)"
            ],
            shortTitle: LocalizedStringResource("Calculate", comment: "App Shortcut tile title"),
            systemImageName: "equal"
        )
        AppShortcut(
            intent: TipIntent(),
            phrases: [
                "Tip with \(.applicationName)",
                "Calculate a tip with \(.applicationName)"
            ],
            shortTitle: LocalizedStringResource("Calculate Tip", comment: "App Shortcut tile title"),
            systemImageName: "dollarsign.circle"
        )
    }
}
