# Privacy Policy

_Last updated: July 24, 2026_

More Voltage builds NumPad with privacy as a priority. We do **not** sell your data, we do **not**
share it with data brokers, and we do **not** track you across other apps or websites. NumPad
requests **no advertising identifier (IDFA)** and performs no cross‑app tracking.

## What NumPad does NOT collect

- **We never collect what you type.** The NumPad keyboard does not record or transmit your
  keystrokes, the contents of the fields you type into, or anything you enter using the keyboard.
  The keyboard extension contains no analytics or networking SDK. It records only the aggregate,
  content-free counters described below.
- We do not collect your name, email, contacts, photos, location, or precise device identifiers.

## What the app collects

The **container app** (not the keyboard) uses Google Firebase to collect a small amount of
diagnostic and usage information. None of it is linked to your identity or used to track you:

| Data | Tool | Purpose |
|------|------|---------|
| Product interaction (e.g. which screens/features are used) | Firebase Analytics | Understand and improve the app |
| Crash reports (stack traces, device/OS model) | Firebase Crashlytics | Diagnose and fix crashes |
| Performance & network timing metadata | Firebase Performance | Improve app performance |
| Remote configuration values | Firebase Remote Config | Adjust defaults without an app update |

In the course of providing these services, Firebase processes a pseudonymous app‑instance
identifier and your IP address (used only for coarse, country‑level analytics and then discarded by
Google). This data is **not linked to your identity** and is **not used for tracking** as Apple
defines it. This matches the app's bundled privacy manifest, which declares Product Interaction,
Crash Data, and Performance Data, all unlinked and non‑tracking.

### Content-free typing quality counters

To improve QWERTY reliability, the keyboard maintains aggregate integer counts such as key taps,
suggestions shown or accepted, corrections applied or reverted, backspace use, page switches, and
short sessions. These counters contain **no letters, words, clipboard text, field contents, app
names, or document identifiers**. They are stored in the shared app-group container. When the
container app next opens, it may send the totals to Firebase Analytics as one product-interaction
event and then clear the local totals.

## Clipboard history and Full Access

If you enable **Full Access** for the NumPad keyboard, optional convenience features become
available (clipboard history, key‑click sound, and haptics). When clipboard history is enabled:

- NumPad reads the current iOS pasteboard only when you open or use its clipboard-history feature;
  it does not monitor the clipboard in the background. iOS may show its own paste permission
  notice, and a host app or managed-device policy can prevent clipboard access.
- Recently captured text is stored **only on your device**, in the iOS Keychain (encrypted at rest).
- It is **never transmitted** off the device and is **not** included in analytics.
- Unpinned entries automatically expire after **1 hour**. An item you explicitly pin remains until
  you unpin, remove, or clear it. History is capped at the 20 most recent items, and an enabled
  kiosk profile may clear it after the configured inactivity timeout.

If you do not grant Full Access, clipboard history, sound, and haptics are simply unavailable; the
keyboard otherwise works normally.

## Profiles, managed configuration, and local persistence

Keyboard profiles contain settings such as pack, theme, layout, behavior, iPad placement, and
optional kiosk policy. Profiles and the active profile identifier are stored in NumPad's iOS
app-group container so the container app and keyboard extension can apply the same configuration.
That local container also holds preferences and content-free diagnostics; profile data does not
contain typed text.

You can explicitly import or export a `.numpadprofile` document. An exported document contains the
selected profile configuration and its name, but excludes purchases, personal dictionary entries,
touch personalization, clipboard history, typing counters, analytics, and diagnostics. NumPad
validates imported documents before asking you to confirm them and does not activate an import
automatically. If you share an exported file using another app or service, that recipient handles
the file under its own privacy policy.

On organization-managed devices, an administrator can provide a built-in profile selection or an
embedded profile document through Apple's Managed App Configuration. NumPad validates the managed
configuration, stores only content-free reconciliation digests and generic failure diagnostics,
and can disable local profile editing while management is active. Managed configuration does not
grant Full Access or enable the keyboard in iOS Settings.

If you explicitly enable NumPad's iCloud sync, eligible settings and profiles are mirrored through
Apple's iCloud key-value service. Clipboard history, personal dictionary entries, touch
personalization, and typing-quality counter files are not included.

## Purchases

Purchases (NumPad Pro and the Finance Pack) are handled by Apple via StoreKit. We never see your
payment details; Apple processes all transactions.

## Data retention and your choices

- Diagnostic/usage data is retained by Firebase per Google's standard retention windows.
- Local profiles, preferences, and app-group configuration remain on the device until you change
  or remove them, the organization replaces its managed configuration, or iOS removes the app's
  stored data.
- NumPad does not provide an in-app analytics opt-out in this build. You can disable clipboard
  history at any time in the app and clear its saved entries from the keyboard's history view.
- Because NumPad has no account and does not expose an app-instance identifier that support can map
  to a requester, we cannot identify or delete Firebase records for a particular person or device.
  Firebase removes that pseudonymous diagnostic and usage data under its retention controls.

## Contact

If you have any questions about this policy or how we handle privacy, email us anytime at
[support@morevoltage.com](mailto:support@morevoltage.com).
