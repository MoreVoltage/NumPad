# NumPad 2.0 — Phase 1: Fully Customizable Keyboard — Design

Status: **DRAFT for review** · Date: 2026-06-21 · Branch: `feat/2.0`

## 1. Goal

Let users redesign the numpad: reorder/add/remove keys, resize keys, set per-key
long-press actions, save multiple named layouts, override per-key colors, and
export/import layouts. Changes sync live to the keyboard extension. The feature is
gated (standalone $4.99 IAP or included in $11.99 Pro). The free/legacy experience
stays byte-for-byte unchanged.

## 2. Locked decisions (from owner)

- **Additive layer**, not a rewrite. Custom layouts are a *new optional* rendering
  path that overrides the grid only when entitled **and** a layout is active.
  Everything else (`KeyboardType`/`Item.pack(type:)`, free users) is untouched.
- **Min deployment target → iOS 16** for the 2.0 line (enables `.draggable`/
  `.dropDestination`; this is a `feat/2.0` change only — 1.8.1 sunset stays iOS 15).
- **SwiftUI islands** for the editor via `UIHostingController`, pushed from the
  existing UIKit `HomeViewController`.

## 3. Data model

New shared model compiled into both targets (lives near `Keyboard.swift`). All
`Codable` for storage + export/import. **Immutable value types** — edits return new
copies (house style).

```swift
struct KeyboardLayout: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String                 // "Work", "Coding", "Accounting"
    var rows: [[KeyDefinition]]      // row-major grid
    var keyScale: Double             // 0.8…1.4 size/padding multiplier (fixes "too compact")
    var schemaVersion: Int           // == KeyboardLayout.currentSchema
    static let currentSchema = 1
}

struct KeyDefinition: Codable, Identifiable, Equatable {
    let id: UUID
    var primary: KeyToken            // tap action
    var longPress: KeyToken?         // optional long-press action
    var label: String?               // glyph override (else derived from token)
    var colorHex: String?            // per-key color override on top of the theme
    var columnSpan: Int              // 1…N grid width (e.g. a wide "0")
}

enum KeyToken: Codable, Equatable {
    case digit(String)               // "0"…"9"
    case decimalSeparator            // locale-aware "." / ","
    case op(String)                  // + - × ÷ = %
    case delete, ret, space, tab
    case cursor(Direction)           // left/right/up/down
    case hide                        // dismiss keyboard
    case calc                        // evaluate expression (inline calculator)
    case snippet(UUID)               // insert a saved snippet
    case pack(KeyboardType)          // jump to a built-in pack row
    case overlay(OverlayKind)        // clipboard / snippets / taxTip
    case noop                        // unknown/forward-compat sink
}
```

**Forward-compat rule:** `KeyToken`'s `Decodable` init maps any unrecognized case to
`.noop`, so a layout authored by a newer build degrades gracefully in an older
extension instead of failing to decode the whole keyboard.

## 4. Storage & sync

Reuse the established cross-process mechanism (no new infra):

- New `Constants` keys (in `SharedExtensions.swift`):
  `customLayouts` (JSON `[KeyboardLayout]`), `activeLayoutID` (UUID string),
  `customKeyboardEnabled` (Bool).
- A small `LayoutStore` (app-group-backed) handles encode/decode + CRUD. The app
  writes; the extension reads. After any write the app calls `SettingsSync.post()`
  (Darwin notification) so a live keyboard re-reads immediately — identical to how
  `UserPrefs`/`Monetization` already propagate.
- Blobs are a few KB — far under the ~50 MB extension ceiling.

## 5. Extension integration

`KeyboardViewController.reloadItems()` gains one branch:

```
if Monetization.isCustomKeyboardEntitled,
   let layout = LayoutStore.activeLayout, customKeyboardEnabled {
       build grid from `layout`     // new mapper → existing Cell/Button views
} else {
       existing Item.pack(type:) path   // unchanged
}
```

A `LayoutRenderer` maps each `KeyDefinition` → the *same* `Cell`/`Button`
configuration the legacy path produces (so haptics, sound, lock chips, overlays,
and theming behave identically). `keyScale` feeds the existing height/padding math
in `StackView`. **Never leave a broken keyboard:** if the active layout is missing,
invalid, or the user isn't entitled (e.g. refund), fall back to the legacy render.

## 6. Editor (SwiftUI island)

New "Customize Keyboard" row in `HomeViewController` → `UIHostingController(rootView:
LayoutEditorView(store:))`. Screens:

1. **Layouts list** — create / rename / duplicate / delete / set-active named layouts.
2. **Grid editor** — live numpad preview; drag-to-reorder (`.draggable`/
   `.dropDestination`); tap a key → inspector; add/remove keys; `keyScale` slider.
3. **Key inspector** (sheet) — pick `primary` + `longPress` action, label override,
   color override, `columnSpan`.
4. **Export / Import** — `ShareLink` of the `Codable` JSON; `.fileImporter` to load.

The editor is **viewable without entitlement** (shows the value); **Apply/Save-active
is gated** → routes to the paywall (`store-preview?source=customize`). Editor logic
(reorder/add/remove/validate) lives in a plain, unit-testable `LayoutEditorModel`
(`@Observable`); SwiftUI is a thin shell over it.

## 7. Entitlement & gating

Add to `Monetization` (plumbing now; IAP wiring is Phase 5):

```swift
static var isCustomKeyboardEntitled: Bool {
    isProEntitled || isCustomKeyboardPurchased || isGrandfathered
}
```

- New `Constants.customKeyboardPurchased` flag + `StoreManager` product
  `numpad.feature.customkeyboard`.
- `isProEntitled` already covers Pro + grandfathered, so Pro owners and
  grandfathered users get it free automatically.

## 8. Migration & compatibility

- **Seed a Default layout** mirroring the current standard numpad the first time the
  feature is enabled, so the editor starts from the familiar grid (not a blank one).
- **Optional import of existing config:** if the user has `CustomKeys` slots or a
  `CustomPackManager` pack, offer to seed the initial layout from them (one-time).
- `schemaVersion` gates future migrations; v1 needs none.
- A `validate()`/`repaired()` pass guarantees every layout retains the essential keys
  (digits 0–9, delete, return) so a user can't save an unusable keyboard.

## 9. Testing strategy (TDD — model first)

RED→GREEN before any UI:

1. **Model:** Codable round-trip; unknown-`KeyToken` → `.noop`; schema field present;
   `repaired()` re-inserts missing essentials; immutability (edits don't mutate source).
2. **LayoutStore:** write→read via a stubbed app-group `UserDefaults`; active-layout
   resolution; corrupt-blob → safe empty.
3. **LayoutRenderer:** `KeyDefinition` → expected cell config for each token; locked
   token renders as locked; fallback when un-entitled.
4. **LayoutEditorModel:** reorder/add/remove/setToken produce correct new layouts;
   validation rejects unusable grids.

UI drag/drop and live extension sync are verified on-device (both phones, iOS 26.5/27.0).

## 10. Build sub-phases

- **1a** Min target → iOS 16 (pbxproj + Podfile). 
- **1b** Model + tests (§9.1).
- **1c** `LayoutStore` + Constants + sync (§9.2).
- **1d** `Monetization.isCustomKeyboardEntitled` + gating plumbing (§7).
- **1e** `LayoutRenderer` + `KeyboardViewController` branch + fallback (§9.3).
- **1f** SwiftUI editor: list → grid → inspector → global settings (§6).
- **1g** Export/import (§6.4).
- **1h** Feature-help stub (full Features & Guide is Phase 4).

## 11. Open questions (need owner input)

1. **iPad scope for v1.** iPad currently uses *pure system sizing* (no height presets).
   Do custom layouts + `keyScale` apply on iPad in v1, or is customization
   **iPhone-only for v1** with iPad keeping system sizing? (Recommend iPhone-only v1.)
2. **Seed from existing config.** Auto-offer to import the user's current `CustomKeys`/
   custom pack into their first layout? (Recommend yes — respects prior setup.)
3. **Standalone vs Pro-only.** Spec says Customizable Keyboard "$4.99 if kept
   separate." Keep the standalone `numpad.feature.customkeyboard` IAP **and** include
   in Pro (recommended), or make it **Pro-only** (simpler catalog, drop the $4.99 SKU)?
```
