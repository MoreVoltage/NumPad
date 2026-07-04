# User-Assignable Long-Press Secondary Functions — Design

**Date:** 2026-07-03
**Branch:** `feat/2.0-ux-overhaul`
**Status:** design only — **no source changes in this doc**. Implementation is a later phase.
**Scope:** the Custom Keyboard v2 model only (`CustomKeyboardConfig` / Top Row / Column 1 / Column 2).
The legacy 3-slot right-side remapper (`CustomKeys.slots`, `CustomKeysView`) is currently hidden
(superseded by the Custom Keyboard) and is explicitly **out of scope** — see §6.

**One-line pitch:** long-pressing a user-assigned key on a Custom Keyboard performs a second,
independently user-chosen action (insert a different literal, a token like `{date}`, or a
function like Tab/Hide-keyboard), the same way long-pressing the fixed "0"/"."/"%"/"=" keys
already opens Clipboard/Snippets/Tax-Tip/Conversion today.

---

## 0. Grounding: what already exists (read before anything below)

- **Model:** `CustomKeyboardConfig` (`NumPad/Libraries/CustomKeyboard/CustomKeyboardConfig.swift`) —
  `topRow`/`column1`/`column2: [String]?` (`nil` = section off, `[]` = on-but-empty), plus `id`,
  `name`, `schemaVersion` (currently `1`, **already reserved for exactly this kind of change** per
  its own doc comment: "so multiple custom keyboards can be layered on later ... without a storage
  migration").
- **Persistence:** `CustomKeyboardStore` — one `Codable` blob in `UserDefaults.group`, write-through
  on every edit, `SettingsSync.post()` → keyboard extension re-reads.
- **Sync:** `CloudSync.syncedKeys` mirrors the *whole* `customKeyboardConfig` blob to
  `NSUbiquitousKeyValueStore`, last-writer-wins, app-side only (§1.3).
- **Editor:** `CustomKeyboardEditorModel` (draft/CRUD) → `CustomKeyboardEditorView` (SwiftUI,
  Configure/Settings segmented control, live preview, secure-field per-slot entry, token palette) →
  hosted by `CustomKeyboardEditorViewController` as a child VC island. Drag-reorder within a section
  (**Option B**, `CustomKeyboardSectionReorderView` + `UICollectionViewDragDelegate`) just landed,
  feature-flagged (`FeatureFlags.customKeyboardDragReorderEnabled` AND'd with a Remote Config kill
  switch, default **ON**) per `docs/plans/2026-07-03-editor-ux-research.md`.
- **Rendering pipeline (live keyboard):** `CustomKeyboardConfig` → `CustomKeyboardLayout.bodyRows`
  (pure, builds `CustomKeyboardCell` enum: `.digit`/`.peripheral`/`.blank`/`.next`/`.globe`/`.zero`/
  `.back`/`.ret` — fixed cells are **never** `.peripheral**, so they can't enter the editable model
  "by construction") → `CustomKeyboardItems.items(for:)` (cell → `Item`) → `Item` → `Cell`
  (UIKit key view) → `StackView`. **Top Row is a separate code path**:
  `KeyboardViewController.customKeyboardTopRow(for:)` builds `Item`s directly from
  `config.topRowKeys`, bypassing `CustomKeyboardLayout`/`CustomKeyboardItems` entirely, and is
  **superseded by the selected pack's row** whenever one is active (§3.5).
- **Existing reserved long-press gestures** (`KeyboardViewController.reloadItems()`), all
  `UILongPressGestureRecognizer(minimumPressDuration: 0.35)`: "0"→Clipboard, "."→Snippets,
  "%"→Tax/Tip, "="→Conversion (entitlement-gated), return-key role→Result Tape (`lastResultTape`
  flag), Next key (repurposed mode only)→Pack Picker. Plus one *positional* guarantee: legacy
  slot index 1 always gets the Snippets long-press unless its title is already ".", so Snippets
  stays reachable when period is remapped — **this guarantee only fires for legacy slots
  (`item.slot != nil`); Custom Keyboard peripherals always have `item.slot == nil`, so it does not
  protect Custom Keyboards today** (§3.4).
- **Continuous-press** ("back"/delete, repeat every 0.1s) is a *different* mechanism
  (`TimerButton`'s `UIControl` tracking, not a gesture recognizer) wired **only** to the fixed
  `.back` cell, which is never `.peripheral` — so it structurally cannot collide with a
  peripheral-cell secondary (§3.6).
- **Monetization:** Custom Keyboard = `Monetization.isCustomKeyboardEntitled` (Pro OR the standalone
  `numpad.feature.customkeyboard` purchase OR grandfathered). No finer-grained gate exists inside
  the feature today.

---

## 1. Model

### 1.1 Storage shape — additive parallel arrays (not a breaking schema change)

**Recommendation:** add three new **optional, parallel, index-aligned** arrays, one per section,
rather than changing `topRow`/`column1`/`column2` from `[String]` to a `KeyAssignment` struct.

```swift
struct CustomKeyboardConfig: Codable, Identifiable, Equatable {
    static let currentSchema = 2   // bumped for documentation; NOT required for decode to succeed

    let id: UUID
    var name: String
    var topRow: [String]?
    var column1: [String]?
    var column2: [String]?
    // NEW — index-aligned with the array of the same section; "" = no secondary at that index
    // (same convention primary arrays already use for an empty/placeholder slot); nil = the
    // section has never had a secondary set (equivalent to "no secondaries anywhere yet").
    var topRowSecondary: [String]? = nil
    var column1Secondary: [String]? = nil
    var column2Secondary: [String]? = nil
    var schemaVersion: Int
    ...
}
```

**Why this over a `[KeyAssignment]`/paired-struct model:** Swift's synthesized `Codable`
conformance (which this struct already relies on — it has a convenience `init`, not a custom
`init(from:)`) decodes new `Optional` stored properties via `decodeIfPresent`, so **old persisted
JSON with no secondary keys decodes cleanly to `nil` with zero migration code** — the exact seam
`schemaVersion`'s doc comment already anticipated. Switching the section type to a struct array
would require a custom `init(from:)` that tries the new shape and falls back to `[String]`, for no
real benefit here (index-alignment is already how `topRow`/`column1`/`column2` themselves work
today, and reordering already operates on parallel `[String]` via `CustomKeyboardReorder.moved`).

**Backward-compatible decoding — the concrete contract:**
- Old config, no secondary fields present → decodes with all three secondary arrays `nil`. No
  crash, no silent data loss, no explicit migration step. **Unit test this as the primary
  regression guard** (§7): decode a fixture JSON captured from the *current* (pre-secondary)
  `CustomKeyboardConfig` shape and assert `topRowSecondary == nil` etc.
- New config, round-tripped through an app build that predates this feature: the **old build's own
  `CustomKeyboardConfig` type has no secondary properties at all**, so if that old build ever
  re-encodes the config (any edit via its `CustomKeyboardEditorModel.update()`), the secondary
  fields are silently dropped on that write — see §1.3 for why this is an accepted, pre-existing
  risk class, not a new one this feature introduces.

**Where a secondary can legally exist:** only at an index whose **primary is non-empty**. Both
existing rendering paths already enforce this shape for primaries and should be left alone rather
than special-cased for secondaries:
- `CustomKeyboardLayout.columnCells` maps an empty primary to `.blank` — a `.blank` cell has no
  slot for a secondary at all, so a secondary at an empty-primary index is simply unreachable by
  construction (recommend: the editor also hides/disables "assign secondary" for an empty slot,
  matching this existing constraint rather than inventing new validation).
- `KeyboardViewController.customKeyboardTopRow(for:)` **filters out** empty-primary entries before
  mapping to `Item`s (`config.topRowKeys.filter { !$0.isEmpty }.map { ... }`) — unlike columns, Top
  Row **compacts** rather than leaving a blank. **This is the one place a naive parallel-array
  change would silently misalign secondaries with primaries**: filtering the primary array alone
  and separately indexing into `topRowSecondary` by original position breaks as soon as an earlier
  entry is empty. The fix is to `zip` primary and (padded) secondary **before** filtering, e.g.
  filter on the pair's primary component, not the primary array alone. Flag this explicitly as a
  correctness trap for whoever implements Phase 1 (§7 test list covers it).

### 1.2 Value vocabulary for a secondary

Reuse the **exact same vocabulary** already legal for a primary slot value — no new concept:
- A typed literal character/short string (subject to the existing `CustomKeys.maxTokenLength = 4`
  cap via `CustomKeyboardEditorModel.sanitize`), or
- A function token (`{space}`/`{tab}`/`{left}`/`{right}`/`{dismiss}`) — these already exceed the
  4-char cap and pass through verbatim because `sanitize` bypasses the length cap for anything in
  `CustomKeys.palette` (an exact-match allowlist, checked *before* truncation).
- **New for secondaries:** the two Date/Time tokens the task calls out (`{date}`/`{time}`), wrapped
  through the *existing* `DateTimeTokens.keyToken(for:)` (`"{dt:date}"`/`"{dt:time}"`, already >4
  chars, same bypass mechanism needed). **Recommendation: do not widen the shared
  `CustomKeys.palette` array** to include these — that array also backs the legacy (hidden)
  slot-remap palette and other read sites; widening it changes behavior for an unrelated screen.
  Instead give `CustomKeyboardEditorModel`'s secondary-sanitize path its own allowlist that unions
  `CustomKeys.palette` with `DateTimeTokens.ordered.map { DateTimeTokens.keyToken(for: $0.token) }`
  restricted to just `date`/`time` (the two the task asks for; the other eight Date/Time tokens can
  follow later with zero model changes — they're already expressible strings).
- **Execution needs no new code path.** `KeyboardViewController.tapped()`'s `default:` case already
  resolves any token string generically: cursor-move tokens perform an action, `{dt:...}` tokens
  resolve via `DateTimeTokens.value(for:now:locale:)`, anything else inserts its own text. Extract
  that switch into a small shared `perform(token:)` helper so the new secondary-long-press handler
  calls the *same* function instead of re-implementing token resolution — pure DRY, not a new
  feature.

### 1.3 iCloud KVS sync (`CloudSync`) impact

- **No new synced key is required.** Secondaries live inside the *same* `customKeyboardConfig`
  blob already in `CloudSync.syncedKeys`, so they ride along for free — one push/pull, no new
  entitlement/plumbing.
- **Known, accepted risk (not new): whole-value, last-writer-wins clobber across app versions.**
  `CloudSync`'s own doc comment already states the policy ("Whole-value, last-writer-wins per
  key"). If a user has two devices, one on a build with this feature and one on an older build, and
  edits happen on both before a sync reconciles, whichever device pushes last wins outright —
  and an **old build's re-encode of the config silently drops secondary fields it doesn't know
  about** (its `CustomKeyboardConfig` type simply has no such properties), so an old-device edit
  that pushes after a new-device secondary was set will erase that secondary from iCloud (and, on
  next pull, from the new device too).
- **Recommendation: accept this as-is, do not build extra protection for Phase 1.** It is the same
  characteristic every other additive field in this blob already has (e.g. `schemaVersion` itself,
  or `handedness` when it was added) — not a risk unique to secondaries. A stronger fix (e.g.
  splitting secondaries into their own synced key so an old build's write literally never touches
  them) is available later at low cost (§6, flagged as a Phase-2-or-later hardening item) if
  telemetry ever shows real-world multi-device/mixed-version data loss; do not build it speculatively.
- No change to `CloudSync.capabilityAvailable`/`isEnabled` gating — secondaries inherit the existing
  Pro + iCloud-opt-in gate exactly like the rest of the synced blob.

---

## 2. Editor UX — how a user assigns a secondary

### Options considered

| # | Interaction | Verdict |
|---|---|---|
| **A** | Long-press a slot in the Configure preview → opens an "Assign secondary" sheet (secure-field entry + token palette, mirroring the existing primary entry section) | **Recommended** |
| **B** | Two-layer keycap: a small corner badge on `KeyCapView` that is itself a second, tiny tap target for secondary entry | Adopt the **badge as a display-only indicator**; reject it as an *interactive* target |
| **C** | Drag a palette token onto a slot, disambiguated from primary-assignment by a modifier (two-finger, distinct drag state, etc.) | **Reject for v1** |

**Why A:** `.onLongPressGesture`/`UILongPressGestureRecognizer` is a single, Apple-owned,
translation-free gesture — it never has to arbitrate against a parent `ScrollView`'s pan
recognizer the way the deleted "Phase-5 springboard" *drag* gesture did (see
`docs/plans/2026-07-03-editor-ux-research.md` §1 for that whole forensic trail). It is exactly the
same gesture *family* the live keyboard already ships five times successfully
(`minimumPressDuration = 0.35`), just relocated to the editor. The resulting sheet reuses
components that already exist and are proven: the secure-field trick (forces the system keyboard,
masks input, mirrors live to the preview slot) and the `tokenPalette` `LazyVGrid` (parameterize it
by an `assigning: .primary | .secondary` case rather than writing a second grid).

**Why B is split (badge yes, tap-target no):** a corner badge gives at-a-glance visibility of which
slots already carry a secondary while building the layout — genuinely useful information density
the sheet-only approach lacks. But making the badge *itself* interactive means a second, much
smaller hit target sharing a 46×48pt cap with the primary tap target, which is both a fat-finger
risk and a fresh VoiceOver problem (a long-press *and* a tiny sub-region tap both need custom
actions). Recommendation: render the badge purely as a decorative summary (`isAccessibilityElement
= false`, exactly like the existing lock-chip pattern in `StackView.configure` already does), and
keep the *only* interactive gesture on the whole keycap (tap → primary entry, unchanged; long-press
→ secondary sheet, new).

**Why reject C for v1:** the drag-reorder feature (Option B from the editor-ux-research doc) is
itself brand new, feature-flagged, and shipped with a Remote Config kill switch *specifically
because* this exact class of gesture risk burned the team once already. Stacking a **second**,
novel, modifier-disambiguated drag interaction (palette → slot, distinct from slot → slot reorder)
on top of a drag feature that hasn't fully soaked in production yet compounds exactly the risk the
team is still de-risking. Revisit only after drag-reorder's kill switch has been removed (i.e., it
shipped clean) and only as a v2 polish, not a launch requirement.

**Consistency with the new drag/palette editor:** the recommended design (long-press → sheet) is
**orthogonal** to `FeatureFlags.customKeyboardDragReorderEnabled` — it attaches to `KeyCapView`
regardless of whether the Configure preview is currently rendering the legacy static rows or the
`CustomKeyboardSectionReorderView` drag surface. If Remote Config kills drag-reorder in production,
secondary assignment is completely unaffected (different gesture, different view layer). This
risk-isolation property is itself worth preserving — do not let a future refactor couple the two.

### Concrete flow

1. Long-press an occupied slot (empty slots — "+" — do not offer a secondary; see §1.1) in the
   Configure preview → sheet opens with two sections: **Primary** (existing secure-field, unchanged)
   and **Secondary** (secure-field + token palette: the 5 function tokens + the 2 new Date/Time
   chips + a "None" chip that clears it).
2. If the slot's *current primary value* renders with a reserved-gesture title (only "." and "%"
   unconditionally; "=" when the Conversion overlay is entitlement-reachable — see §3.2), show an
   inline warning: *"Long-press is reserved for [Snippets/Tax & Tip/Conversion] while this key
   reads '…'. Change the key or the long-press won't trigger your secondary."* Still allow saving
   (the assignment is stored and becomes live the moment the user changes the primary away from the
   colliding title) rather than blocking the flow.
3. `CustomKeyboardEditorModel` gains `secondaryKey(at:)` / `setSecondaryKey(_:at:)`, mirroring
   `key(at:)`/`setKey(_:at:)` exactly (same padding-to-index, same sanitize path per §1.2).
   `moveKey(in:from:to:)` is updated to call `CustomKeyboardReorder.moved` on **both** the primary
   and (padded-to-same-length) secondary arrays with the identical `(source, destination)` pair, so
   a drag-reorder never desyncs the two — `moved` is a pure, deterministic function of its inputs,
   so applying it twice with the same indices preserves alignment.
4. Analytics: `custom_keyboard_secondary_assigned` event, matching the existing naming convention
   (`custom_keyboard_section`, `custom_keyboard_reorder`, `custom_keyboard_handedness`).

---

## 3. Keyboard-side gesture design (CRITICAL)

### 3.1 Full inventory of existing long-press / continuous-press behavior

| Key / condition | Mechanism | Target | Notes |
|---|---|---|---|
| "0" | `UILongPressGestureRecognizer(0.35)` | Clipboard History | always attached |
| "." | `UILongPressGestureRecognizer(0.35)` | Snippets | always attached |
| "%" | `UILongPressGestureRecognizer(0.35)` | Tax/Tip | always attached |
| "=" | `UILongPressGestureRecognizer(0.35)` | Conversion | only if `Monetization.isConversionOverlayReachable(...)` |
| return-key role | `UILongPressGestureRecognizer(0.35)` | Result Tape | only if `UserPrefs.lastResultTape` |
| Next key (imageName "next") | `UILongPressGestureRecognizer(0.35)` | Pack Picker | **only** when `UserPrefs.repurposeNextKey` is on; otherwise the key's long-press is the **system's** keyboard-switcher list (`.allTouchEvents` → `handleInputModeList`) — never attach a competing gesture here |
| Globe key (imageName "globe") | `.allTouchEvents` → `handleInputModeList` | System keyboard list | system-owned, same caution as above |
| legacy slot index 1 (`item.slot == 1`) | `UILongPressGestureRecognizer(0.35)` | Snippets | guarantee so Snippets stays reachable if "." is remapped away — **`item.slot` is always `nil` for Custom Keyboard peripherals, so this guarantee does not extend to Custom Keyboards today** (§3.4) |
| "back" (delete) | `TimerButton` continuous-press (`.valueChanged` every 0.1s via `Timer.every`, armed after `continuousPressTimeInterval` from touch-down) | repeat-delete | **not** a `UIGestureRecognizer` — lives at `UIControl` touch-tracking level; wired only to the fixed `.back` cell |

### 3.2 The shadowing problem: title-based matching, not identity-based

`reloadItems()`'s gesture-attachment `switch` keys off **`(item.title, item.imageName)`** — it has
no concept of "is this the reserved key" vs. "is this a user key that happens to render the same
title." Concretely: `CustomKeyboardItems.item(for: .peripheral(key))` builds
`Item(title: CustomKeys.displayName(for: key), actionToken: key)`, and `displayName(for: "%")`
falls through to `default: return token` (`"%"` is not a named function token) — so **a Custom
Keyboard peripheral slot whose primary literal is `"%"` renders with title `"%"` and matches
`case ("%"?, _)` exactly like the reserved key would**, silently attaching the Tax/Tip long-press
to it. This is not hypothetical or new — it is the *current, already-shipping* behavior for the
legacy right-side slots too (remap slot 0 to "%": tapping inserts "%", long-pressing still opens
Tax/Tip, not anything slot-specific). Secondary design must work *with* this existing behavior, not
invent a new precedence system on top of it.

**Recommended precedence rule:** *reserved title/imageName/role-matched gestures always win.* A
peripheral cell's secondary long-press is only attached in the same catch-all branch where the
existing `item.role == .returnKey && UserPrefs.lastResultTape` check already lives — i.e., **after**
every reserved case has had first refusal. Concretely, the only titles a peripheral cell's *primary*
value can realistically collide with are:
- `"."` and `"%"` — unconditional reserved gestures, always shadow a secondary.
- `"="` — reserved gesture only exists when `Monetization.isConversionOverlayReachable(...)` is
  true for the current user; when false, "=" carries no reserved gesture and a secondary **is**
  attachable there.
- `"0"` cannot collide — the "0" bottom-row key is a fixed `.zero` cell, never `.peripheral`; a user
  cannot make a peripheral slot literally the "reserved 0" (they can type "0" as a peripheral's
  *primary*, and it would visually read "0", but the reserved-gesture switch also matches on
  `imageName` for `next`/`globe`/`back`, none of which peripherals ever carry — only the *title*
  string `"0"` matters, and yes, a peripheral primary of literal `"0"` **would** shadow a secondary
  there too by the same title-matching mechanism; call this out in the editor's collision-warning
  copy alongside "." and "%").
- Next/globe/return/back cannot collide at all — those are fixed cells, never `.peripheral`
  (§1.1); no title collision is possible because peripherals never carry an `imageName`, and the
  return-key collision path requires `item.role == .returnKey`, which peripherals never have either.

### 3.3 New gesture attachment for a secondary

Add exactly **one** `UILongPressGestureRecognizer(minimumPressDuration: 0.35)` per cell whose
`item.secondaryToken != nil` **and** whose title/imageName/role did not already match a reserved
case above — same threshold, same API, same "one recognizer per cell" shape as every existing
reserved gesture (not a novel composition; no stacking of multiple gesture recognizers on one
cell). Because the trigger is *data-driven* (which token to perform varies per cell, unlike the 5
fixed reserved handlers which always call the same static selector), the implementation needs a
small closure-capturing shim (`UILongPressGestureRecognizer(target:action:)` can't close over
per-cell data via a bare `@objc` selector) — a lightweight per-cell target object or associated
closure, not a new gesture-arbitration concern. Resolve the assigned token by calling the shared
`perform(token:)` helper extracted in §1.2 — same execution path a primary token already uses.

Add the matching `accessibilityHint`/`UIAccessibilityCustomAction` pair, exactly mirroring the
existing 4 (Clipboard/Snippets/Tax-Tip/Conversion) — VoiceOver users get "double-tap and hold" hint
text plus an equivalent explicit custom action, since VoiceOver intercepts real long-press gestures.

### 3.4 Fixing (or documenting) the Snippets-reachability gap for Custom Keyboards

Today, if a Custom Keyboard's Column 1 index 1 isn't literally ".", Snippets has **no** guaranteed
reachable long-press on that keyboard at all (the `item.slot == 1` guarantee never fires for
peripherals). Two options:
- **(a) Self-serve via secondary** — document the gap; a user who wants Snippets reachable on a
  fully custom layout assigns it as a secondary themselves. No forced behavior.
- **(b) Seed a default** — auto-suggest (not force) a Snippets secondary on Column 1 index 1 when a
  Custom Keyboard is first built with a non-"." primary there.

**Recommendation: (a) for Phase 1/2.** It's zero engineering, doesn't surprise anyone with an
assignment they didn't make, and secondaries are precisely the mechanism that makes (a) viable for
the first time (today there is no self-serve path at all). Revisit (b) only if usage data shows
real users landing on Snippets-unreachable custom layouts and getting stuck.

### 3.5 Top Row secondaries are shadowed whenever a pack is selected — not a new gap

`customKeyboardTopRow(for:)` already prefers the **selected pack's** row over the user's custom Top
Row whenever one is active — this is existing, intentional behavior (packs still cycle through the
top row via next/🌐 even with a Custom Keyboard active). Secondaries assigned to the custom Top Row
inherit this exactly: they are only *rendered/reachable* while `effectiveKeyboardType == .default`
(no pack selected); cycling to Math/Finance/Symbols/etc. replaces the whole row, secondaries and
all, with that pack's row (which has no secondary concept). This is not a new limitation
secondaries introduce — it's an existing property of Top Row/pack interaction that secondaries
simply inherit. **Column 1/Column 2 have no such caveat** — they render unconditionally regardless
of pack selection, so column secondaries are always live. Worth a one-line comment at the
implementation site so it isn't "discovered" later as a regression.

### 3.6 Timing interplay with `Button`'s continuous-press timer

**Conclusion: no interplay, by construction.** Continuous-press (`forContinuousPressWithTimeInterval`)
is wired **exclusively** to the fixed `.back` cell (`imageName == "back"`), which — like `.zero`,
`.next`, `.globe`, `.ret` — is never a `.peripheral` cell and therefore can never carry a secondary
(§1.1's structural exclusion). A secondary's `UILongPressGestureRecognizer` and the delete key's
`TimerButton` tracking can never be attached to the same cell, so the two mechanisms' respective
timings (0.35s gesture threshold vs. a 0.1s-interval repeat timer armed after
`continuousPressTimeInterval`) never have to arbitrate against each other. Call this out explicitly
in code comments at the attachment site so a future refactor doesn't accidentally make "back"
assignable and reintroduce the question for real.

---

## 4. Rendering

### 4.1 `Item` gains a `secondaryToken: String?`

Threaded alongside the existing `token`/`slot` fields, populated only by the two Custom-Keyboard
construction paths (`CustomKeyboardItems.item(for:)` for columns, `customKeyboardTopRow(for:)` for
the top row — with the `zip`-before-filter fix from §1.1). Legacy pack/slot `Item`s never set it
(`nil`), so nothing about existing rendering changes for non-Custom-Keyboard keys.

### 4.2 Corner badge — reuse the existing lock-chip pattern, don't invent a new one

`StackView.configure` already draws a small corner-anchored `UIImageView` + tooltip `UILabel`
overlay for locked premium keys (`Keyboard/Views/StackView.swift`, ~L66–104), sized via
`KeyMetrics.lockChipSize`/`lockTooltipFontSize` (idiom-aware: 12pt/16pt and 9pt/11pt). Recommend the
**same mechanic**, but simpler content (a plain filled dot rather than an icon + text tooltip — a
secondary's label doesn't need to be legibly spelled out on the key, just its *presence* signaled;
tapping/long-pressing reveals what it does) and a **new** idiom-aware constant,
`KeyMetrics.secondaryBadgeSize` (recommend 8pt/12pt — deliberately smaller than the lock chip so the
two are visually distinct if ever seen side by side, even though §4.3 shows they never actually can
be).

**Placement:** add it inside `Cell.configure(_:roundedCorners:touchDown:tapped:)` itself, not
`StackView.configure`. The lock chip lives in `StackView` because it needs cross-cutting context
`Item` doesn't carry (`keyboardType`, `row`, `Monetization.isKeyLocked`); a secondary badge only
needs `item.secondaryToken`, which is entirely self-contained on the `Item` — putting it in `Cell`
keeps the two concerns at the altitude where their inputs actually live (higher cohesion, matches
the "many small, focused files" principle already followed elsewhere in this codebase).

**Position/RTL:** top-trailing corner via `trailingAnchor`, exactly like the lock chip — Auto
Layout's `trailingAnchor` already flips correctly under RTL with zero extra code (the lock chip
already relies on this).

**Accessibility:** `isAccessibilityElement = false` on the badge itself (matching the lock chip's
own `lock.isAccessibilityElement = false`); the cell's own `accessibilityHint`/custom action (§3.3)
carries the actual spoken affordance.

### 4.3 No collision with the lock chip

Lock chips only render for **pack** keys (`Monetization.isKeyLocked(pack:row:)`, gated by
`StackView`'s `isCustom` branch, whose own comment already states "no pack lock-chips since custom
keys are not pack-gated"). Secondary badges only render for **Custom Keyboard peripheral** keys.
These two paths are already mutually exclusive in `StackView.configure` today — there is no
scenario where both would need to draw on the same cell, so no stacking/precedence logic is needed
between them.

### 4.4 iPad scaling

Follow `KeyMetrics`'s existing idiom-aware pattern exactly (`isPad` check, larger constant on iPad)
— `secondaryBadgeSize` is one more entry in the same enum, no new scaling mechanism.

---

## 5. Monetization

**Recommendation: no new gate, no new Constants key, no new deep-link source.** Secondaries are a
pure extension of the Custom Keyboard's existing config surface, and the Custom Keyboard itself is
already fully gated (`activeCustomKeyboardConfig` returns `nil` — no rendering at all, custom or
otherwise — unless `Monetization.isCustomKeyboardEntitled`). Since a secondary literally cannot
exist without an active Custom Keyboard config, it inherits that gate for free at every layer:
- **Live keyboard:** no `activeCustomKeyboardConfig` → no custom rendering → no peripheral cells →
  no secondary tokens to attach gestures to. Nothing new to check.
- **Editor:** `CustomKeyboardEditorView`'s existing `entitled`/`lockedPrompt` check already blocks
  the entire Configure screen (including the new secondary-assignment sheet, since it's reached
  from the same preview) when not entitled.
- **Do not introduce a second, finer-grained tier** (e.g., requiring full Pro even for a standalone
  Customizable-Keyboard buyer) — there's no product ask for it, it contradicts
  `Monetization+CustomKeyboard.swift`'s own framing of the feature as additive/uniform, and it would
  add a second paywall dimension to explain in marketing/screenshots for a sub-feature, not a
  distinct product.
- **No new `LockFunnelCounters`/deep-link source** — those exist for *locked* key taps; secondaries
  have no partially-locked state (all-or-nothing with the existing entitlement), so there is nothing
  new to attribute.

---

## 6. Phasing

### Phase 1 — Model + keyboard-side engine (dark; no editor UI)

Ships the data model, persistence, rendering, and execution — fully unit-tested — behind a feature
flag, with **no way for a real user to set a secondary yet** (editor lands in Phase 2). Mirrors
exactly how `CustomKeyboardEditorModel`/`CustomKeyboardStore` themselves were built and tested
before their UI existed.

- `CustomKeyboardConfig`: add the three `*Secondary` arrays + bump `schemaVersion` to 2 (§1.1).
- Thread `secondaryToken` through `CustomKeyboardCell` → `CustomKeyboardLayout.columnCells` →
  `CustomKeyboardItems.item(for:)` → `Item.secondaryToken` → `customKeyboardTopRow(for:)` (with the
  zip-before-filter fix).
- Extract `perform(token:)` from `KeyboardViewController.tapped()`'s token switch; call it from both
  the primary path (existing) and the new secondary path.
- `reloadItems()`: attach the data-driven secondary long-press gesture per §3.3, respecting the
  reserved-gesture precedence rule (§3.2).
- `Cell`: corner badge per §4.2, `KeyMetrics.secondaryBadgeSize` added.
- New flag: `FeatureFlags.customKeyboardSecondaryEnabled` (local, default off during development)
  ANDed with a Remote Config kill switch (`custom_keyboard_secondary_enabled`), mirroring the exact
  `dragReorderActive` precedent — same escape-hatch shape the team just built for drag-reorder,
  reused rather than reinvented.

**Phase 1 test list:**
- `CustomKeyboardConfigTests` (new or extended): decode a captured pre-secondary JSON fixture →
  all three `*Secondary` are `nil`; round-trip encode/decode with secondaries set; `schemaVersion`
  unaffected by decode success either way.
- `CustomKeyboardLayoutTests`: `.blank` primary never yields a `.peripheral` regardless of a
  populated (hypothetical) secondary array at that index; column secondary stays index-aligned with
  primary through `columnCells`.
- `CustomKeyboardItemsTests`: `.peripheral` with a secondary produces an `Item` whose
  `secondaryToken` matches; without one, `nil`.
- `KeyboardViewControllerTests` (or the nearest existing harness): `customKeyboardTopRow(for:)`
  correctly pairs primary/secondary across a filtered (compacted) Top Row — the specific correctness
  trap from §1.1.
- Precedence rule as a pure function if extracted (e.g. `reservedGestureShadows(title:imageName:
  role:...) -> Bool`): "." and "%" always shadow; "=" shadows only when conversion is reachable;
  next/globe/back/return/0(fixed) never reachable via peripheral in the first place.
- `perform(token:)` helper: same output for a given token regardless of call site (primary vs.
  secondary), covering literal/space/tab/cursor/dismiss/`{dt:date}`/`{dt:time}`.

### Phase 2 — Editor UX + rollout

- `CustomKeyboardEditorModel`: `secondaryKey(at:)`/`setSecondaryKey(_:at:)`, secondary-specific
  sanitize allowlist (§1.2), `moveKey` updated to move primary+secondary in lockstep.
- `CustomKeyboardEditorView`: long-press → "Assign secondary" sheet (§2), reserved-title collision
  warning banner, decorative corner badge in the editor's `KeyCapView` preview (mirrors §4.2's
  live-keyboard treatment for visual consistency between editor and live keyboard).
- Analytics event `custom_keyboard_secondary_assigned`.
- Flip `customKeyboardSecondaryEnabled` on for internal/TestFlight builds, verify on-device (below),
  then default it on for production the same way `customKeyboardDragReorderEnabled` already is.

**Phase 2 test list:**
- `CustomKeyboardEditorModelTests`: `setSecondaryKey`/`secondaryKey(at:)` CRUD; `moveKey` keeps
  primary and secondary aligned after a reorder; sanitize allowlist accepts `{dt:date}`/`{dt:time}`
  and the 5 function tokens verbatim (no truncation) while capping arbitrary literals at 4 chars;
  clearing a primary to empty also disables/hides secondary assignment for that index (no orphaned
  secondary reachable in the UI, even though the model may still hold stale data at that index until
  overwritten — decide whether `setKey("", at:)` also clears the paired secondary; recommend **yes**,
  to avoid a confusing "invisible" secondary reappearing if the slot is refilled).
- `CustomKeyboardEditorViewSnapshotTests` (if this codebase has any UI snapshot harness) or manual
  QA: collision-warning banner appears/disappears correctly as the primary field changes.

**Device-verification checklist (both phases' on-device gate, per the project's own history of
gesture surprises never showing up in Simulator):**
- [ ] iPhone: long-press a peripheral key with a secondary → correct action fires; tap still does
      the primary; no double-fire.
- [ ] iPhone: peripheral key whose primary is literally "." or "%" → long-press opens
      Snippets/Tax-Tip (reserved), **not** the assigned secondary; editor shows the collision warning.
- [ ] iPad: same two checks, plus badge legibility at the larger `KeyMetrics` scale.
- [ ] VoiceOver on: secondary is reachable via the custom action even with the long-press gesture
      intercepted; badge itself is silent (not double-announced).
- [ ] RTL locale (e.g. Arabic/Hebrew): badge still renders top-trailing correctly relative to
      reading direction; key order still reverses as expected.
- [ ] Handedness = left vs. right: column secondaries follow the column to whichever side it's
      rendered on.
- [ ] Cycle packs via next/🌐 while a Custom Keyboard is active: Top Row secondary disappears
      when a pack's row supersedes it, reappears when back to no-pack — confirm this reads as
      expected behavior, not a bug, per §3.5.
- [ ] Full Access **off**: secondary long-press still fires (matches existing overlay gestures,
      which don't require Full Access — only haptics/sound do).
- [ ] Two-device iCloud sync smoke test (§1.3): set a secondary on device A, confirm it appears on
      device B after a sync cycle; accept (do not "fix") the known last-writer-wins clobber case if
      B is on an older build.
- [ ] Remote Config kill switch: flipping `custom_keyboard_secondary_enabled` off remotely reverts
      live keyboards to primary-only behavior without an app update (mirrors the drag-reorder
      precedent's verification).

---

## 7. Open questions, with recommended defaults

| # | Question | Recommended default |
|---|---|---|
| 1 | Struct-array vs. parallel-array model? | Parallel optional arrays (§1.1) — additive, zero-migration decode |
| 2 | Can a secondary exist without a primary at that index? | No — matches existing `.blank`/filter behavior; editor hides the affordance |
| 3 | New synced iCloud key for secondaries? | No — rides along in the existing `customKeyboardConfig` blob (§1.3) |
| 4 | Build extra protection against cross-version KVS clobber? | Not for Phase 1/2 — accepted pre-existing risk class; revisit only if telemetry shows real loss |
| 5 | Editor assignment UX? | Long-press → sheet (Option A) + decorative corner badge; reject interactive badge and palette-drag-with-modifier for v1 |
| 6 | Precedence when a primary's title collides with a reserved gesture ("." / "%" / conditionally "=" / literal "0") | Reserved gesture always wins; editor warns, does not block saving |
| 7 | Fix the pre-existing Custom-Keyboard Snippets-reachability gap (§3.4)? | No forced default — self-serve via secondary; revisit only with usage evidence |
| 8 | Monetization tier for secondaries? | None — inherits the existing Custom Keyboard entitlement entirely (§5) |
| 9 | Legacy `CustomKeys.slots` (hidden) editor — extend secondaries there too? | No — scope to Custom Keyboard v2 only |
| 10 | Rollout mechanism? | New local flag ANDed with a Remote Config kill switch, mirroring `customKeyboardDragReorderEnabled` exactly |
| 11 | Does clearing a primary also clear its paired secondary? | Yes — avoids a stale secondary silently reappearing when the slot is refilled |

---

## Sources (internal)

- `NumPad/Libraries/CustomKeyboard/CustomKeyboardConfig.swift`, `CustomKeyboardStore.swift`,
  `CustomKeyboardEditorModel.swift`, `CustomKeyboardEditorView.swift`, `CustomKeyboardLayout.swift`,
  `CustomKeyboardReorder.swift`, `CustomKeyboardSectionReorderView.swift`, `Handedness.swift`
- `NumPad/Libraries/Customization/Monetization+CustomKeyboard.swift`
- `NumPad/Libraries/Customization/Editor/KeyCapView.swift`
- `Keyboard/KeyboardViewController.swift`, `Keyboard/Libraries/Item.swift`,
  `Keyboard/Libraries/CustomKeyboardItems.swift`, `Keyboard/Views/Cell.swift`,
  `Keyboard/Views/Button.swift`, `Keyboard/Views/StackView.swift`, `Keyboard/Views/KeyMetrics.swift`
- `NumPad/Libraries/SharedExtensions.swift` (`CloudSync`, `CustomKeys`, `DateTimeTokens`,
  `FeatureFlags`, `RemoteConfigManager`, `Constants`)
- `docs/plans/2026-07-03-editor-ux-research.md` (Phase-5 springboard failure forensics, Option
  A/B/C drag-reorder comparison, current-editor-strengths inventory)
- `docs/plans/2026-06-24-custom-keyboard-v2-design.md` (original v2 design + as-built notes)
- `graphify query` passes: "custom keyboard config slots item rendering long press overlays",
  "long press gesture recognizer overlay clipboard snippets tax tip conversion pack picker",
  "Button continuous press timer repeat delete haptic", "CloudSync iCloud KVS sync custom keyboard
  config persistence", "CustomKeyboardConfig CustomKeys slot token decode Codable backward
  compatible", "CustomKeysView editor palette drag assign slot KeyCapView
  CustomKeyboardEditorModel", "CustomKeyboardStore CustomKeyboardReorder SectionReorderView save
  load defaults"
