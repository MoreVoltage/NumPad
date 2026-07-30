# Keyboard Studio Cross-Device Design

**Date:** 2026-07-29
**Status:** Approved for implementation
**Branch:** `codex/keyboard-studio-ux`
**Visual references:**

- iPhone: `/tmp/numpad-ux-concepts/.superpowers/brainstorm/8532-1785175219/content/keyboard-studio-full-storyboard-restored.html`
- iPad: `/tmp/numpad-ux-concepts/.superpowers/brainstorm/8532-1785175219/content/keyboard-studio-ipad-storyboard.html`

## Product intent

NumPad should feel like a small utility that is immediately understandable, not an administration
console. Most users open the container app once to enable the keyboard, choose its appearance and
key set, and then use the extension. The primary experience therefore answers three questions:

1. Is my keyboard ready?
2. What will it look like?
3. What is the next useful change I can make?

Corporate-grade functionality remains available, but under one simplified Advanced surface.

## Information architecture

The ordinary app has exactly three destinations:

- **Keyboard** — live preview, Try It field, and the most useful keyboard choices.
- **Features** — calculator tools, reusable text, and custom keys.
- **Help** — setup state, practical guides, privacy, support, restore, and version.

A gear on Keyboard opens **Advanced** as a secondary surface:

- Saved setups
- Kiosk mode
- Move setups
- Managed settings, only when managed ownership exists

There is no Dashboard destination, no Pro tab, and no ordinary top-level Profiles or Kiosk item.
Legacy controllers may remain as implementation details while routes migrate, but no visible
ordinary path may lead to the old list-style home.

## Visual language

Use the approved Keyboard Studio direction:

- warm near-white canvas with ink-like primary text;
- blue for ordinary primary action and purple only for Advanced identity;
- large, calm headings; small uppercase section labels; low-contrast separators;
- rounded cards used for meaningful grouping, not for every row;
- restrained shadows and motion; no gradients;
- selection uses text or glyph plus border, never color alone;
- all interactive targets are at least 44 points.

Dynamic Type, VoiceOver, RTL, Bold Text, Reduce Motion, increased contrast, dark appearance, and
long localized strings are first-class states.

## iPhone layout

Keyboard is the default tab. Its first viewport contains:

1. readiness/status hero with a direct repair action when needed;
2. truthful live keyboard preview;
3. Try It text field;
4. quick-change actions for Appearance, Choose keys, Size & feel, and Letters when available.

Quick changes open focused push screens. Appearance owns theme, match-dark-mode, rounded corners,
and grid. Choose keys uses plain-language tiles: Numbers, Calculations, Prices, Measurements,
Date & time, Symbols, and Programming. Size & feel owns height, number order, haptics, sound, and
cursor control. Letters appears only when the QWERTY Remote Config and entitlement gate permit.
Autocorrect remains off by default.

Features and Help use the same design language, with content grouped by user outcome rather than
internal implementation names. Locked items open one focused Pro sheet sourced from the attempted
feature. Product prices come from StoreKit.

## iPad layout

The iPad app uses the same product model with more useful spatial organization.

### Regular-width landscape

- A lightweight navigation/sidebar region selects Keyboard, Features, Help, or Advanced.
- The upper workspace uses a canvas plus contextual inspector.
- The keyboard preview is a separate dock, constrained to the bottom safe area and permanently
  visible.
- The dock shows the keyboard at a meaningful physical scale, centered by default with utility
  rails where space permits. It must not be a floating screenshot or a card inside the scroll view.

### Portrait and narrower multitasking

- The upper controls collapse into one scrollable column.
- The keyboard dock remains fixed to the bottom.
- Content receives a bottom inset equal to the dock height so the last control remains reachable.
- At compact widths, the iPhone tab presentation is acceptable, but the preview remains anchored
  when the screen is presenting Keyboard Studio.

### Dock behavior

- The dock reflects the selected theme, key set, height, number order, grid, rounded corners, and
  QWERTY availability.
- It updates immediately after settings changes and after `SettingsSync` notifications.
- It uses existing placement preferences. Automatic selects the clearest layout for current width;
  explicit Left/Center/Right choices are honored when viable and degrade safely when not.
- Only explicit chooser samples may display a keyboard away from the bottom.

## First-install iPad height choice

During first-install onboarding on iPad, after the value explanation and before Try It, ask:
“How tall should your NumPad be?” Show Compact, Regular, Tall, and Kiosk as visual samples.

- Selecting Compact, Regular, or Tall writes the shared preference and posts `SettingsSync`.
- Kiosk is labelled Pro. An unentitled tap opens the existing StoreKit-backed Pro surface and does
  not change the effective height.
- After purchase/restore, Kiosk can be selected without restarting onboarding.
- Existing users are not interrupted; the choice appears in Size & feel.
- Skipping preserves the existing default.

## Kiosk entitlement

Both the Kiosk height and Kiosk mode require `Monetization.isProEntitled` through the existing
single-source helpers. The UI may explain Kiosk before purchase, but cannot activate a Kiosk setup,
write a Kiosk policy, or report readiness as configured for an unentitled user. Grandfathered users
retain their existing entitlement behavior.

Kiosk mode uses plain language: guided preparation, inactivity reset choices, Try It confirmation,
and an explicit note that the user enables Guided Access in iOS. Administrative authentication and
transactional rollback behavior must remain intact.

## Truthful preview

The preview is model-driven and non-interactive. It reads real pack layouts rather than hard-coded
key labels, reflects number order and geometry preferences, preserves glass theme fidelity, and
uses `KeyboardProfileApplier.probe` for projected saved setups. It does not mutate settings while
previewing. VoiceOver treats the preview as one described image rather than dozens of fake keys.

## Compatibility and safety

- Preserve app-group writes and Darwin settings synchronization.
- Preserve StoreKit 2 purchases, restore, grandfathering, Remote Config, QWERTY kill switch,
  import validation, kiosk rollback, and old deep links.
- Never log typed text, clipboard contents, snippets, or imported setup contents.
- Never add Glide code or promises.
- Never claim Full Access can be detected reliably.
- Never archive, upload, or submit to App Store Connect in this phase.

## Acceptance criteria

- iPhone launches into the three-tab Keyboard Studio shell; Dashboard is gone from visible UI.
- Every visible destination is functional and written in plain language.
- iPad uses the additional width and keeps the truthful keyboard preview anchored at the bottom in
  landscape, portrait, and multitasking.
- The iPad first-install height choice works, and Kiosk height/mode cannot activate without Pro.
- Existing settings, profiles, imports, purchases, deep links, and keyboard behavior remain intact.
- Automated unit/UI coverage and signed simulator verification cover phone and iPad matrices.
