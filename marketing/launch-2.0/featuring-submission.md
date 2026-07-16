# Apple Featuring Nomination — ready to submit

Source: `marketing/appstore/featuring-pitch.md` (full one-pager, still accurate). This file is
the condensed, form-ready version. **Status: 2.0.0 is LIVE since 2026-07-07** — the pitch's old
"re-verify against master" caveat is resolved; all claims verified against shipped `master`.

## Where to submit

App Store Connect → sidebar **"Featuring Nominations"** → New Nomination.
(If the account doesn't show that section, the fallback is the promote form at
https://developer.apple.com/contact/app-store-promotion/)

## Form fields — paste-ready

**Nomination name:** NumPad 2.0 — Live Math in a keyboard

**App:** NumPad: Your Number Keyboard (Apple ID 1072547160)

**What's new / description (short):**
NumPad 2.0 turns a numeric-keypad keyboard extension into a computing surface: type
"84.50*1.18" in any app and the answer floats above the cursor before you reach "=". The
same offline engine powers zero-setup App Intents — "Calculate with NumPad" works in Siri
and Spotlight the moment the app installs — and on iOS 26 the new Glass theme pair renders
real Liquid Glass material with a matched dark twin. A drag-and-drop Custom Keyboard editor
(UIKit + SwiftUI interop inside the extension's ~50MB ceiling), iPad side-panel overlays with
pointer hover and drag-and-drop, and a Kiosk-height preset for point-of-sale iPads round out
the release.

**Why feature it (angles, pick per campaign):**
- **Platform-technology adoption:** App Intents with zero-setup App Shortcuts; real Liquid
  Glass on iOS 26 with graceful pre-26 fallback; iPad treated as its own idiom (side panels,
  pointer hover, drag-and-drop, per-idiom heights).
- **No-subscription story:** every purchase is a one-time non-consumable with Family Sharing
  enabled on all eight products — in a category dominated by subscriptions.
- **Privacy story:** the keyboard extension ships with no analytics SDK at all and never logs
  a keystroke; Full Access powers only clipboard/haptics/sound, on-device.
- **Accessibility:** overlay keys expose VoiceOver labels and custom actions (e.g. the "%" key's
  "Show tax and tip calculator" action), the keypad scales with Dynamic Type, and Reduce Motion is
  honored on the live-math chip and onboarding — accessibility depth beyond the category norm.

**Timing hooks:** 2.0.0 released July 7, 2026. In-App Event "NumPad 2.0 Launch" scheduled
(see `asc-update-runbook.md`). iOS 26 Liquid Glass adoption is current-cycle relevant.

**Availability:** all territories, 50 localized metadata sets, iPhone + iPad, iOS 16+.

## Submission notes

- Keep pricing out of the nomination body (editorial evaluates product/tech, not price).
- Don't claim competitive superiority — factual platform-adoption depth only.
- I can fill and submit the form via browser automation once you say go — you review the
  final field contents first (it's outward-facing).
