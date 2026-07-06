# NumPad 2.0 — App Store Description

Status: DRAFT for App Store Connect. Not submitted. All prices/features verified against
`CLAUDE.md`, `NumPad/Products.storekit`, and source as of 2026-07-04 (branch `feat/2.0-ux-overhaul`).

---

## Promotional text (≤170 chars)

> NEW: Live math preview computes as you type. Liquid Glass themes, Siri Shortcuts, and a
> drag-and-drop custom keyboard editor. 6 packs, one lifetime price.

Character count: 168.

---

## Keywords (≤100 chars, comma-separated, no spaces per Apple convention — count includes commas)

> numpad,number pad,calculator,keyboard,math,finance,programmer,unit converter,tip calculator,ipad

Character count: 99.

---

## App Store description

**Above-the-fold (first 3 lines — visible before "more")**

```
Type a number, get an answer. NumPad adds a full numeric keypad to every keyboard on your
phone — and now it computes as you type: finish "1200*0.0825" and the answer floats above
your cursor before you even reach for the "=" key.
```

**Full description**

```
NumPad turns your iPhone or iPad's cramped default row of numbers into a real numeric
keypad — the one you already know from a calculator or a POS terminal — available in every
app that takes text input. Banking app, spreadsheet, group chat, delivery form: NumPad sits
right there as a keyboard, no app-switching required.

NEW IN 2.0: LIVE MATH, WHILE YOU TYPE
Start typing an expression — "84.50*1.18", "250-20%", "3*12+40" — and a floating result
chip appears above the cursor before you finish. Tap it to insert the answer, or keep
typing to refine the expression. It's the same calculator engine that powers the "="
key and Siri, just faster to reach.

A NUMPAD FOR YOUR ACTUAL WORK
Swap in a specialized row of keys for what you're doing, six packs to choose from:
 • Finance — currency symbols for quick price entry
 • Symbols & Science — π, √, ^, °, and other math notation
 • Programmer — hex prefixes and bitwise operators
 • Date & Time — insert today's date or the current time with one tap
 • Units & Conversion — length, mass, and temperature keys with a live offline converter
 • Cooking & Baking — fraction keys (½ ⅓ ¼) plus a cups-to-milliliters converter
Long-press "%" for a two-step tax + tip calculator. Long-press "." for reusable text
snippets. Long-press "0" for clipboard history. Long-press "=" for the unit/recipe
converter. Every calculation lands on a running result tape you can revisit.

BUILT ON APPLE'S NEWEST FRAMEWORKS
NumPad 2.0 speaks Siri: "Calculate with NumPad," "Convert units with NumPad," and
"Calculate a tip with NumPad" work the moment the app is installed — no setup, no
configuration, and every packs' math runs fully offline. On iOS 26 devices, the optional
Glass theme uses real Liquid Glass material — refractive, depth-aware, and matched to a
dark twin so it looks right in both appearances.

A CUSTOM KEYBOARD, YOUR LAYOUT
Pro unlocks a keyboard you build yourself: keep the numpad in the middle and add up to
three of your own sections around it — a top row and two side columns — filled from a
drag-and-drop key library (characters, cursor arrows, Tab, Hide Keyboard, or live
date/time tokens). Choose left- or right-handed layout for your columns. Every edit
previews live before you save it.

DESIGNED FOR IPAD TOO
On a wide iPad, overlays (clipboard, snippets, converter) open as a side panel instead of
covering your work, keys respond to pointer hover, and clipboard/snippet rows support
drag-and-drop straight into the host app. Pick from four keyboard heights — Small,
Default, Tall, or (Pro) Kiosk-sized — so the keypad fits a phone in one hand or an iPad
mounted at a checkout counter just as well.

KIOSK-READY FOR POINT-OF-SALE AND FRONT-DESK USE
The Pro Kiosk height preset was built for iPads that live somewhere other than a pocket —
a receptionist's check-in tablet, a self-serve order screen, a warehouse counting station.
It's the same numeric keypad your team already knows, sized to be legible and tappable
from arm's length, with zero extra hardware or backend to stand up.

SEVENTEEN THEMES, 17 WAYS TO MAKE IT YOURS
From clean White to deep Indigo to the new iOS 26 Liquid Glass pair — pick a look, or let
Automatic Dark Mode switch it for you.

PRIVACY, THE WAY A KEYBOARD SHOULD WORK
NumPad's keyboard extension never logs analytics and never tracks your keystrokes — full
access is used only for clipboard history, haptics, and key-click sounds, entirely on your
device. There's no subscription: every pack and Pro are one-time purchases, and every
purchase is Family Sharing enabled, so up to five family members can use what you bought
at no extra cost.

WHAT YOU GET FOR FREE
The default numpad, Math keys, 15 classic themes, snippets, and clipboard history — no
paywall, no trial clock, no account required.

WHAT PRO ADDS ($11.99, one time)
Every pack, the Liquid Glass themes, the custom keyboard editor, iCloud sync across your
devices, and the Kiosk height preset — bundled once, forever, no subscription.
```

---

## What's New in 2.0

```
NumPad 2.0 is here — the biggest update since launch.

• Live Math Preview: a floating result chip computes your expression as you type, before
  you reach for "="
• Two new packs: Units & Conversion (with a live offline converter) and Cooking & Baking
  (fractions + a cups-to-ml converter)
• Siri & Shortcuts support: "Calculate with NumPad," "Convert units with NumPad," and
  "Calculate a tip with NumPad" — no setup required
• Liquid Glass premium themes for iOS 26, with a matched dark twin
• A completely rebuilt Custom Keyboard editor: drag-and-drop key library, live preview,
  left/right handedness toggle, and date/time token keys
• A new interactive first-run walkthrough that gets you enabling and trying the keyboard
  in under a minute
• Bigger keyboard heights for iPad, including a new Kiosk-sized preset for point-of-sale
  and front-desk use
• Every purchase is now Family Sharing enabled
• Countless polish passes: key-press micro-interactions, refreshed paywall copy, and
  under-the-hood reliability fixes
```

---

## Notes for whoever submits this

- **Pricing verified against `NumPad/Products.storekit`**: Pro lifetime $11.99, early-bird
  $5.99 (72h window, pre-2.0 users only — not mentioned above since it's not a new-buyer
  price), six packs at $1.99 each ($11.94 à la carte total). Do **not** quote the $8.99
  Pro price floated in `docs/plans/2026-07-03-pack-lineup-proposal.md` — that's a proposal,
  not shipped/priced in ASC as of this doc's date.
- **Family Sharing**: `CLAUDE.md` states all eight non-consumables are Family Sharing
  enabled as of 2.0. Older `marketing/asc/` runbooks (1.8-era, pre-dating the 6-pack
  catalog) only cover 2 products — those are historical and superseded here.
- **Kiosk height** is Pro-gated and iPad-only (falls back to Tall on iPhone and for
  unentitled users) — the B2B paragraph above is intentionally light-touch positioning,
  not a claim of dedicated kiosk-mode APIs (there is no Guided Access/Single App Mode
  integration in the code).
- **Custom Keyboard** is Pro-only; free users see packs + right-side slot remapping only.
- The keyboard extension **does not** use Firebase/Analytics — the "never tracks your
  keystrokes" claim is accurate per `CLAUDE.md`'s Analytics section.
