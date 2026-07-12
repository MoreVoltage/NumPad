# NumPad 2.0 — Apple Editorial Featuring Pitch

One-pager for App Store editorial submission (App Store Connect > App Store Editorial
"Nominate app for consideration" flow, or an Apple developer-relations contact). Framed around
platform-technology adoption depth, not just feature breadth — grounded in source, not marketing
copy.

---

## The pitch, in one paragraph

NumPad is a numeric-keypad keyboard extension that treats Apple's newest developer frameworks as
core product, not decoration: a custom keyboard extension deep enough to host a live,
self-computing math engine; the first (and, at time of writing, one of very few) keyboard-utility
apps offering **App Intents** for Siri/Shortcuts/Spotlight; a **Liquid Glass** material theme on
iOS 26; and a completely custom, drag-and-drop keyboard-layout editor built entirely with UIKit +
SwiftUI interop inside the tight ~50MB memory ceiling of a keyboard extension. It's also a
one-time-purchase app in a category dominated by subscriptions, with Family Sharing enabled on
every purchase.

---

## Platform technology depth

### App Intents (Siri, Shortcuts, Spotlight)
`NumPad/Libraries/AppIntents/` implements three `AppIntent`s — `CalculateIntent`,
`ConvertUnitsIntent`, `TipIntent` — registered as **zero-setup App Shortcuts**
(`NumPadShortcuts: AppShortcutsProvider`). The moment the app is installed, "Calculate with
NumPad," "Convert units with NumPad," and "Calculate a tip with NumPad" work in Siri and
Spotlight — no user configuration, no separate Shortcuts-app setup. Each intent reuses the exact
same engine that powers the keyboard itself (`Calculator`, `UnitConverter`, `TaxTipMath`), so the
math a user gets from Siri is provably identical to what they'd get from the "=" key — not a
parallel reimplementation. `CalculateIntent` even writes into the shared `ResultTape`, so a
number computed via Siri shows up in the keyboard's own result history. All three intents run
fully offline and are deliberately **not** entitlement-gated — a monetization decision made in
the code's own doc comments: a locked keyboard key is the product, but a free Siri calculation is
marketing surface area.

### Liquid Glass (iOS 26)
`KeyboardTheme` ships a `.glass`/`.glassDark` pair that renders the real iOS 26 Liquid Glass
material (`KeyboardViewController.applyGlassBackdrop`, gated on `#available(iOS 26.0, *)`) with a
translucent-color fallback on earlier OS versions — so the same theme selection degrades
gracefully rather than being iOS-26-exclusive. The light/dark twin exists specifically so
automatic-appearance users get a glass look in both modes, not just one.

### Custom keyboard extension, built to the platform's real constraints
The Custom Keyboard editor (`NumPad/Libraries/CustomKeyboard/`) is a from-scratch layout system —
three optional peripheral sections (top row, two side columns) around a fixed numpad, seeded from
the user's existing setup, editable via a `UICollectionView` drag-and-drop palette
(`CustomKeyboardKeyLibraryView` + `CustomKeyboardSectionReorderView`) wrapped for SwiftUI. It was
rebuilt once already after a free-form drag-grid version failed on-device — the current
single-page design is the result of that iteration, and it respects the extension's genuinely
tight memory ceiling (~50MB) throughout. Slot entry uses a deliberately clever constraint: each
slot is a secure text field, which forces the system keyboard for input (blocking third-party
keyboards from interfering) while the typed character surfaces live in the visible slot preview —
a detail worth a sentence in any technical write-up of the app.

### Family Sharing, done right
All eight non-consumable in-app purchases — Pro lifetime, the early-bird Pro price, and all six
individual packs — are Family Sharing enabled. Apple's Family Sharing entitlement for
non-consumables is a one-way door once turned on (cannot be reverted without deleting and
recreating the product), which the team treated as a deliberate, permanent commitment rather than
a toggle to revisit.

### Accessibility
Accessibility labels, hints, and accessible elements are present across both the container app's
SwiftUI custom-keyboard editor surfaces (`CustomKeyboardKeyLibraryView`,
`CustomKeyboardSectionReorderView`, `CustomKeyboardEditorView`) and the keyboard extension's own
UIKit views (`KeyboardViewController`, `Cell`, `StackView`, `MathPreviewChipView`,
`SnippetsListView`) — accessibility support reaches all the way into the extension's custom key
grid, not just the container app's settings screens.

### iPad as a real platform, not a scaled-up phone
On iPads ≥700pt wide, overlays (clipboard history, snippets, the unit/recipe converter) present
as a 360pt trailing side panel instead of covering the user's work, keys respond to pointer
hover, and clipboard/snippet rows support native drag-and-drop into the host app
(`KeyboardViewController.installOverlayBeside`). Keyboard height is a first-class, per-idiom
setting (`KeyboardHeightPreset`) — iPad gets its own taller base heights than iPhone, plus a
Kiosk-sized preset for iPads used at a distance (checkout counters, front-desk check-in), not just
a device-width-driven clamp.

### One-time purchase, in a subscription-first category
Most third-party keyboard apps in this category (SwiftKey-adjacent competitors) monetize via
subscription. NumPad is entirely non-consumable IAPs — buy once, own it, no recurring charge —
which is both a user-respecting stance and a genuine differentiator worth noting for any "great
apps, no subscriptions" or "one-time purchase" editorial angle Apple runs periodically.

---

## Why this is an editorial fit, not just a feature list

Every item above is a **platform-technology adoption story**, which is the angle App Store
editorial teams have historically favored over pure feature announcements: new-OS-feature
adoption (Liquid Glass, App Intents), platform-idiom respect (iPad-specific UI, not a stretched
phone layout), and a monetization model (Family Sharing, no subscription) that aligns with themes
Apple has promoted before. The app also has a clean privacy story to lead with if asked: the
keyboard extension carries **no analytics SDK at all** and never logs a keystroke — Full Access is
used only for clipboard, haptics, and key-click sound, entirely on-device.

---

## Verification notes (for whoever sends this)

- All claims above are grounded in source, originally as of `feat/2.0-ux-overhaul` @ `6725209c`
  and re-confirmed after the branch merged to `master` (`a1cdef7c`). **2.0.0 is live on the
  App Store as of 2026-07-07** — the submission-ready field text lives in
  `marketing/launch-2.0/featuring-submission.md`.
- Do not claim "years ahead" or competitive superiority language to Apple's editorial team —
  this pitch sticks to factual platform-adoption depth, which is what they evaluate on.
- Pricing mentioned nowhere above deliberately — editorial pitches should lead with product/tech,
  not price; if asked, current live pricing is Pro lifetime $11.99, six packs at $1.99 each (see
  `description-2.0.md`'s verification notes for the caveat about a since-proposed $8.99 Pro price
  that is **not** yet shipped).
