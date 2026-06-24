# Custom Keyboard v2 — structured editor (fixed numpad + editable peripherals)

**Date:** 2026-06-24
**Branch:** `feat/2.0-ux-overhaul` (design only; implement in a fresh session)
**Status:** Design approved (geometry locked). NOT implemented. **Supersedes the Phase-5 springboard editor.**

## Why (on-device findings, iPhone 16 Pro)

The Phase-5 free-form **springboard** custom-keyboard editor failed on device:
1. **Drag-and-drop does not work at all** — the long-press→drag reorder never fires on the device.
2. **The globe (🌐 next-keyboard) key disappears** — the free-form grid dropped it.
3. **The 0–9 number keys were editable/movable** — they should be fixed.

Root cause: a free-form draggable grid is the wrong model. The fix is a **constrained, structured editor**: the numpad is fixed; only the *peripheral* key sections are customizable, and each key is defined by typing a character (no drag gesture at all). This resolves all three issues by construction (the numpad — incl. 🌐 and 0–9 — is always rendered and never editable).

## Approved design

### Geometry (LOCKED)
- **Fixed numpad** (never editable): digits 0–9, decimal separator, delete, return, and the **🌐 switch key**. Always rendered.
- **3 customizable sections, each with its own on/off switch:**
  - **Top Row** — a horizontal strip of keys directly above the numpad (today's "pack keys" position).
  - **Column 1** and **Column 2** — two vertical strips of keys, **BOTH on the handed side** (right-handed → both to the RIGHT of the numpad, stacked side-by-side; left-handed → both to the LEFT).
- **Handedness:** a NEW Left/Right-handed setting controls which side the columns sit on. (Independent of the existing "7-8-9 on top" reversed mode.) Add to `UserPrefs` (app group + `SettingsSync`).
- Column length aligns to the numpad's row count; top-row width aligns to the numpad width. (Tune during implementation.)

### Per-key definition (no drag)
- Tap a peripheral key cell → it becomes the focused **single-character text field** → the **system keyboard appears** → the user types the character → focus **auto-advances to the next cell** in that section. Each cell is its own text field.
- **Feasibility caveat (confirmed):** iOS has **no public API to force the stock keyboard or block third-party keyboards** in a text field. We set a plain single-char field; we cannot guarantee the system keyboard. The tap → type → auto-advance flow works regardless of which keyboard is active.
- Char limit per key: TBD (1 char, or a short string like today's 4-char custom keys). Decide in implementation; 1–2 chars matches "type the character."

### Editor UI
- Three **section switches** (Top Row · Column 1 · Column 2) to enable/disable each section.
- A **live preview** of the numpad with the enabled sections + their current keys, reflecting handedness.
- Tapping a preview cell focuses it for entry; auto-advance on each character.
- A **Left/Right-handed** toggle.
- **Pro-gated** (custom keyboard remains a Pro feature; reuse `Monetization.isCustomKeyboardEntitled` or fold into the custom-pack gate).

### Mental model
The custom keyboard becomes **"a custom pack (top row) + editable side columns"** — exactly the owner's framing. It extends the existing custom-pack (top row) and right-side-slots (→ Column 1) concepts rather than the free-form grid.

## Data model (new — replaces the free-form layout for this feature)
```
struct CustomKeyboardConfig {        // app group, SettingsSync, Codable
    var topRow: [String]?            // nil/empty = section off
    var column1: [String]?
    var column2: [String]?
    var handedness: Handedness       // .left / .right
}
enum Handedness { case left, right }
```
Much simpler than `KeyboardLayout`/`KeyDefinition`. Likely **fold in** the existing `CustomPack` (= top row) and the `CustomKeys` right-side slots (= Column 1), so there's one peripheral-customization concept.

## Keyboard-extension rendering
The extension must render, in order, per handedness:
`[handed-side columns] + numpad (fixed, incl. 🌐 in the bottom row) + top row above`.
Today it renders: top pack row + numpad + a single RIGHT column (the 3 `CustomKeys` slots). Generalize to: optional Top Row + up to 2 columns on the **handed** side + the fixed numpad. The 🌐 key stays in the numpad's bottom row at all times (the disappearing-globe bug must not recur — add a guard/test that the switch key is always present when `needsInputModeSwitchKey`).

## What this supersedes / cleanup
- **Drop the springboard editor:** `SpringboardGridView.swift`, the free-form `LayoutGridEditorView` rewrite, and `SpringboardLayout.swift` reflow model are obsolete (the drag UX is gone). Decide: delete them, or keep `SpringboardLayout` only if any math is reusable (it isn't, really).
- `LayoutListView` / multi-layout machinery (`KeyboardLayout`, `LayoutStore`, `LayoutEditorModel`, `ensurePrimaryLayout`) is likely **replaced** by the simpler `CustomKeyboardConfig`. Decide whether to retire it.
- Phase-5 commits stay in history; this is a forward redesign, not a revert.

## Open items to settle at implementation kickoff
1. Char limit per peripheral key (1 vs short string).
2. Max keys per section (column length vs numpad rows; top-row width).
3. Whether to unify `CustomPack` + `CustomKeys` slots into `CustomKeyboardConfig`, and the migration for anyone who set those today.
4. Handedness default (right).
5. Keep vs delete the springboard/layout code.
6. Test: the 🌐 key is always present; sections render on the correct (handed) side; per-key entry + auto-advance; Pro gating.

## Next step
Implement in a **fresh session** (substantial rebuild; this design intentionally written to survive the context boundary). Suggested order: data model + handedness pref (TDD) → keyboard-extension rendering (left/right columns + always-globe) → the structured editor UI (sections + per-key entry + auto-advance) → Pro gating + guide copy → device-verify.
