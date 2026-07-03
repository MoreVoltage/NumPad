# Custom Keyboard Editor — Drag-and-Drop UX Research

**Date:** 2026-07-03
**Branch:** `feat/2.0-ux-overhaul`
**Author:** research pass (no source changes)
**Triggered by:** owner finds the current typing-based editor "clunky" and wants a
drag-and-drop (iOS-springboard-style) editor instead.

This document does three things: (1) establishes exactly why the earlier free-form
drag-and-drop editor ("Phase-5 springboard") failed on device, using the deleted
source + commit history as evidence, not just the retrospective prose in the design
doc; (2) inventories what the *current* (typing-based) editor gets right and must be
preserved; (3) proposes 2-3 concrete drag-and-drop redesigns that avoid the original
failure, with framework choice, effort, and risk for each, plus one recommendation.

---

## 1. Root cause of the Phase-5 springboard failure

### 1.1 What shipped, and what broke

The springboard editor was built in three commits on `feat/2.0-ux-overhaul`
(2026-06-24) and deleted the same day, ~9 hours later:

| Commit | Description |
|---|---|
| `f27e435f` | `SpringboardLayout.swift` — pure reorder math (flatten/rebuild/moving/insertionIndex/isLocked) |
| `6d89e7bb` | `SpringboardGridView.swift` — the actual drag gesture + reflow-animation view |
| `2cab1f67` | `fix(customkbd): recover springboard lift state on gesture cancel` — a patch attempting to fix gesture-cancellation edge cases |
| `eecd9798` | **deletion** — "The structured custom keyboard v2 replaces the Phase-5 free-form springboard editor (broken on device)." 13 source + 8 test files removed. |

`docs/plans/2026-06-24-custom-keyboard-v2-design.md` records three on-device findings
(iPhone 16 Pro) that motivated the rewrite:

1. **"Drag-and-drop does not work at all — the long-press→drag reorder never fires on
   the device."**
2. **"The globe (🌐 next-keyboard) key disappears — the free-form grid dropped it."**
3. **"The 0–9 number keys were editable/movable — they should be fixed."**

The design doc's diagnosis is terse ("a free-form draggable grid is the wrong
model"). Reading the actual deleted code confirms three **distinct, independent**
defects — not one root cause wearing three hats:

### 1.2 Defect 1 — the gesture itself: known-fragile SwiftUI composition, not a one-off bug

`SpringboardGridView.swift` attached this gesture to **every cell**:

```swift
LongPressGesture(minimumDuration: 0.3)
    .sequenced(before: DragGesture(coordinateSpace: .named(coordinateSpaceName)))
```

This lived inside a `ZStack` inside a `GeometryReader`, which itself was rendered
inside a `ScrollView` in the parent `LayoutGridEditorView`, which was hosted as a
`UIHostingController` **pushed onto the app's UIKit `UINavigationController`**
(`CustomKeyboardCoordinator.push` → `presenter.show(viewController, sender:)`).

That is four independent gesture-owning layers stacked on top of each other:
`UINavigationController`'s edge-swipe-back recognizer → the hosting controller's
UIKit/SwiftUI bridge → the `ScrollView`'s pan recognizer → the per-cell sequenced
long-press+drag. The code's own doc comments already show the team fighting
instability *before* the on-device failure was even discovered — the class-level
comment reads:

> "the lift gesture can be interrupted (the scroll view steals the touch, the user
> releases without dragging, or a re-render re-identifies the gesture) and
> `.onEnded` may never fire."

...and an entire commit (`2cab1f67`, same day) was spent adding recovery logic for
exactly that ("settle the lifted key on every non-active value ... so the grid can
never soft-lock"). That's a team patching around symptoms of gesture-arbitration
instability, not a team that had a working gesture and hit an isolated bug.

Web research on this exact pattern corroborates it as a **known, general SwiftUI
pitfall**, not something specific to this codebase:

- Nesting a custom drag/long-press gesture inside a `ScrollView` is a documented
  conflict class: "Adding a drag gesture to a View inside a ScrollView blocks
  scrolling" (Apple Developer Forums), because "in SwiftUI there is no way to
  programmatically cancel gesture recognition — once the gesture recognizer begins,
  only it can decide when to stop" (danielsaidi.com, "Using complex gestures in a
  SwiftUI ScrollView").
- `UIHostingController`-hosted gestures interacting with UIKit hit-testing are
  reported to behave inconsistently between Simulator and device, and even to crash
  (`EXC_BAD_ACCESS`) in some hitTest-override workarounds — a documented
  UIKit/SwiftUI bridging incompatibility.
- Simulator vs. device touch-timing differences are a common cause of "gesture never
  activates on device but works in Simulator/Preview" reports for exactly this
  `LongPressGesture.sequenced(before: DragGesture())` composition.

**Conclusion:** the "never fires on device" symptom is consistent with the parent
`ScrollView`'s pan gesture recognizer (or the hosting-controller/nav-controller
gesture stack) winning arbitration before the per-cell long-press could activate —
a well-documented failure mode of composing custom SwiftUI gestures inside scroll
containers, made worse by being hosted three layers deep in a UIKit nav stack.

### 1.3 Defect 2 — the globe key: a modeling gap, not a gesture bug

`KeyboardLayoutItems.swift` (the extension-side renderer for custom layouts) built
the **entire** item grid from `layout.rows` (the user-editable `KeyDefinition`
grid), with no reserved or guaranteed slot for the system-required next-keyboard
key:

```swift
static func items(for layout: KeyboardLayout, returnTitle: String) -> [[Item]] {
    layout.rows.map { row in row.compactMap { item(for: $0, returnTitle: returnTitle) } }
        .filter { !$0.isEmpty }
}
```

Meanwhile, the **legacy/fixed** grid gets its globe key from separate, conditional
logic that lives in `KeyboardViewController.swift` (`needsInputModeSwitchKey &&
UserPrefs.repurposeNextKey`, current line ~639) — logic that has nothing to do with
`Item.pack(type:)`'s static grid and is applied on top of it. The free-form
layout model had no equivalent contract ("this slot always exists regardless of
what the user drew"), so nothing guaranteed the switch key survived a user's edit.
This is a **structural absence**, independent of whether the drag gesture worked.

### 1.4 Defect 3 — movable digits: "locked" meant "undeletable," not "fixed position"

`SpringboardLayout.isLocked` only gated the delete (⊖) badge:

```swift
/// Whether a token is an essential the editor keeps un-removable (digits 0–9, delete,
/// return). These can still be **reordered** — the lift/drag gesture attaches to them like
/// any other key; "locked" only withholds the ⊖ delete badge...
static func isLocked(_ token: KeyToken) -> Bool {
    KeyboardLayout.essentialTokens.contains(token)
}
```

The model had exactly one axis of protection (deletable vs. not) and no concept of
"pinned position" at all. Every cell — digit or not — was `KeyDefinition` in one flat
list that `SpringboardGridView` would happily drag anywhere.

### 1.5 Synthesis

> **The free-form grid conflated three different guarantees the keyboard actually
> needs (always-present, fixed-position, and deletable-or-not) into a single flat,
> fully-draggable list — and implemented the "drag" half with a custom, multi-layer
> SwiftUI gesture composition (`LongPressGesture.sequenced(before: DragGesture())`
> nested in `ScrollView` + `GeometryReader`, hosted via `UIHostingController` pushed
> onto a UIKit nav stack) that is a well-documented fragile pattern and simply never
> activated on physical devices.**

The v2 rewrite (`cc88b5ed` → `6d73a4dc`, current) fixed all three **by construction**
— fixed numpad geometry is never part of the editable model at all, and it dropped
drag gestures entirely in favor of tap-to-select + type. That's exactly why it's
reliable *and* why the owner now finds it clunky: the fix over-corrected away from
gestures rather than away from the specific broken gesture composition.

---

## 2. What the current (v2) editor gets right — must be preserved

Read from `NumPad/Libraries/CustomKeyboard/CustomKeyboardEditorView.swift`,
`CustomKeyboardEditorModel.swift`, `CustomKeyboardLayout.swift`, and
`NumPad/Controllers/CustomKeyboardEditorViewController.swift` (via
`graphify query "custom keyboard editor CustomKeyboardEditorView slots"` and direct
reads):

1. **Secure-field system-keyboard trick.** Each slot's entry field is a
   `SecureField` (`isSecureTextEntry`), which forces the system keyboard and blocks
   third-party keyboards (an iOS security behavior repurposed here) — the *only*
   confirmed way to guarantee free-text entry of arbitrary characters regardless of
   the user's installed keyboards. Content is masked in the field itself but shown
   live in the **preview slot** because the binding writes through to the model on
   every keystroke.
2. **Configure / Settings segmented control.** `EditorMode.configure` (live preview
   + per-slot entry) vs. `.settings` (handedness picker). Simple, cheap, orientation
   for two very different tasks.
3. **Live preview** (`previewSection`) — a numpad-shaped grid: 3 fixed digit rows
   (never editable — rendered via `fixedCap`, not a `Button`), the fixed bottom row
   (`next` / `0` / `⌫` / `⏎`), an optional scrollable Top Row strip, and up to two
   optional side columns whose screen side follows `model.handedness`.
4. **Section on/off model**, not free-form add/remove: `CustomKeyboardEditorModel.Section
   = { topRow, column1, column2 }`, each `nil` (off) or `[String]` (`[]` = on-but-empty).
   Capacity is fixed per section (`topRowCapacity = 10`, `columnCapacity = 3`,
   aligned to the 3 numpad rows) — there is no free-form grid to overflow.
5. **`CustomKeyboardStore` persistence** — app-group-backed, `Codable`, write-through
   on every edit, `SettingsSync.post()` on change so a live keyboard extension picks
   it up immediately (same mechanism as `UserPrefs`/`Monetization`).
6. **Pro gating** via `Monetization.isCustomKeyboardEntitled`, re-checked on
   `scenePhase == .active` (catches a purchase/restore completed while backgrounded).
7. **Hosting is simple now**: `CustomKeyboardEditorViewController` embeds the SwiftUI
   view as a **child view controller** filling its own view (`addChild` +
   `view.addSubview` + `didMove`), *not* pushed as a separate `UIHostingController`
   the way the springboard coordinator did it. The SwiftUI root is a plain `List`
   (UITableView-backed) of `Button`s — there is no custom gesture recognizer
   anywhere in the current editor, which is a large part of *why* it's stable.
8. **Fixed geometry is locked by construction**: digits, delete, return, and 🌐 are
   never `Section` members — they can't enter the draggable/editable model at all,
   so any redesign that keeps sections as the unit of edit inherits this guarantee
   for free.

Any drag-and-drop redesign should touch only the **within-section ordering** of
already-typed keys (and optionally, assigning a function token via drag), leaving
1–6 above untouched.

---

## 3. Proven iOS drag-and-drop patterns (compatible with this project's actual floor)

**Important floor correction:** `CLAUDE.md`'s header says "Minimum deployment
target: iOS 15.0," but that line is stale for this branch. The actual project
settings on `feat/2.0-ux-overhaul` are already **iOS 16.0**
(`Podfile: platform :ios, '16.0'`, and `IPHONEOS_DEPLOYMENT_TARGET = 16.0` throughout
`project.pbxproj`), per commit `eaa49246` ("bump minimum deployment target to iOS 16
for 2.0"). **`.draggable()`/`.dropDestination()` (iOS 16+) are therefore safe to use
outright on this branch, not merely "conditional."** (Flag this doc/CLAUDE.md
discrepancy for a docs fix separately — not in scope here.)

Patterns surveyed:

- **`UICollectionViewDragDelegate` / `UICollectionViewDropDelegate`** (iOS 11+) —
  the mature, most battle-tested reorder API (Reminders, Files, Home). Long-press
  triggers the drag automatically; UIKit owns gesture arbitration end-to-end, so it
  does not compete with a parent `ScrollView`'s pan recognizer the way a custom
  SwiftUI gesture does. Bridged into SwiftUI via `UIViewRepresentable`.
  **This codebase already has a working, device-verified sibling pattern**: iPad
  overlay rows (`ClipboardHistoryView`, `SnippetsListView`) use
  `tableView.dragInteractionEnabled = true` +
  `UITableViewDragDelegate.itemsForBeginning(session:at:)` today, to drag rows out
  into the host app. Same family of API (`UIDragInteraction`/drag-delegate), proven
  on-device in this exact codebase — just for export rather than in-place reorder.
- **SwiftUI `List` + `.onMove(perform:)`** (iOS 13+) — Apple's own list-reorder UX
  (Reminders/Mail edit-mode drag handles). Under the hood this is still a
  UITableView-backed reorder gesture, not a custom SwiftUI `DragGesture` — so it
  does not suffer the springboard's failure mode. Documented limitation: "drag and
  drop on `List` seems to work only on iPad, not iPhone" applies to the *generic*
  `onDrag`/`onDrop` modifiers on arbitrary `List` content, **not** to `.onMove` with
  `EditMode`, which is the standard, iPhone-reliable list-reorder mechanism used
  system-wide.
- **SwiftUI `.draggable()` / `.dropDestination()`** (iOS 16+, `Transferable`) — the
  modern replacement for `onDrag`/`onDrop` (`NSItemProvider`-based). Newer, less
  field-mileage than `UICollectionView` or `List.onMove`, but well-documented by
  Apple and free of the "sequenced custom gesture nested in ScrollView" failure
  mode *as long as the drop targets aren't themselves nested inside another
  scrolling/gesture-heavy container* — same hit-testing caution as before, just
  with a cleaner Apple-maintained gesture underneath instead of a hand-rolled one.

Known device pitfalls to design around (from the sources above and this codebase's
own history):
1. Never attach a custom long-press/drag gesture to a cell that also lives inside a
   `ScrollView`/`GeometryReader` stack — that composition is what killed the
   springboard. Prefer an API where UIKit (or Apple's `Transferable` stack) owns
   gesture arbitration, not a hand-assembled `.sequenced(before:)` chain.
2. Keep reorder scope **local to one section's small, fixed-capacity list**
   (max 10 items for Top Row, 3 for a column) — never a single free-form grid mixing
   the fixed numpad with editable peripherals. This is already how the v2 model is
   shaped; a redesign should reuse that shape, not flatten it.
3. If hosting a `UICollectionView` via `UIViewRepresentable` inside the existing
   SwiftUI `List`-based editor, avoid nesting it inside another scrollable
   container — give it its own non-scrolling, fixed-height cell/section, consistent
   with pitfall #1.

---

## 4. Proposed designs

### Option A — Per-section `List` + `.onMove` (native list reorder)

- **Interaction model:** Each enabled section (Top Row / Column 1 / Column 2)
  renders as its own small SwiftUI `List` (or `List`-in-`Section`) of typed keys.
  Entering Edit mode reveals the standard `≡` drag handle; long-press-drag reorders
  within that section exactly like Reminders. Assigning *what* a key is still uses
  the existing secure-field tap-to-type flow (unchanged) — reorder and assignment
  become separate steps, both first-class.
- **Framework:** Pure SwiftUI, `List` + `ForEach.onMove(perform:)` +
  `EditMode`/`EditButton`. iOS 13+ (well under the current iOS 16 floor).
- **Why it avoids the failure:** No custom gesture is written at all — `.onMove` is
  backed by UITableView's native reorder recognizer, the same mechanism Reminders/
  Mail/Settings use, which does not compete with a parent scroll view the way the
  springboard's `LongPressGesture.sequenced(before: DragGesture())` did. Reorder
  scope is a single small section list (≤10 items), never the fixed numpad — digits/
  delete/return/🌐 are structurally outside the model, same as today.
- **Effort:** Low–Medium (2–4 days): swap each section's static `HStack` of
  `slotButton`s for a `List`+`ForEach` with `.onMove`, wire `onMove` to
  `CustomKeyboardEditorModel` (array move on the section's `[String]`, already
  value-semantic), keep everything else (secure-field entry, Configure/Settings,
  persistence, gating) unchanged.
- **Risk:** **Low.** Reuses Apple's most road-tested reorder mechanism and this
  project's own "structured, per-section" model rather than reintroducing a
  free-form grid.

### Option B — `UICollectionView` compositional layout + native drag delegate (bridged via `UIViewRepresentable`)

- **Interaction model:** Replace the numpad-shaped `previewSection` grid (or just
  the editable Top Row / column strips) with a small `UICollectionView` per
  section, using `UICollectionViewDragDelegate`/`DropDelegate` (`.reorder` intent)
  for long-press-drag reordering with the system's native lift/scale/haptic
  feedback — closer to the "springboard feel" the owner is asking for than a plain
  list row, since compositional layout can render a horizontal key strip (Top Row)
  or a vertical stack (columns) with the same visual key-cap chrome as today.
- **Framework:** UIKit `UICollectionView` + drag/drop delegates (iOS 11+), bridged
  into the existing SwiftUI editor via `UIViewRepresentable`.
- **Why it avoids the failure:** UIKit owns the entire gesture lifecycle
  end-to-end (no hand-assembled `.sequenced(before:)` chain, no competing
  `ScrollView` pan recognizer inside a `GeometryReader`). This codebase has a
  **proven, device-verified sibling implementation already shipping** —
  `ClipboardHistoryView`/`SnippetsListView` use
  `UITableViewDragDelegate.itemsForBeginning(session:at:)` for iPad drag-out today —
  so the team has direct, working precedent for this exact API family, just for a
  different use (drag-out vs. in-place reorder).
- **Effort:** Medium (4–6 days): build the `UIViewRepresentable` wrapper, the
  `UICollectionViewCompositionalLayout` for a horizontal strip and a vertical
  column, wire `UICollectionViewDragDelegate`/`UICollectionViewDropDelegate` with
  local-reorder (`.move`) drop proposals, keep the fixed numpad entirely outside
  the collection view (a separate, non-interactive SwiftUI view as today).
- **Risk:** **Low–Medium.** More native "springboard" feel and the most road-tested
  drag API, but more integration surface (a new `UIViewRepresentable` bridge, and
  care to keep it non-nested inside another scroll container) than Option A.

### Option C — SwiftUI `.draggable()` / `.dropDestination()` reorder (iOS 16+, `Transferable`)

- **Interaction model:** Each section's key caps become `.draggable(cell)` sources
  and `.dropDestination(for:)` targets within that section only (never across the
  fixed numpad); dropping on another cap in the same section swaps/reorders it,
  with Apple's built-in drag preview and animation.
- **Framework:** SwiftUI `Transferable` + `.draggable()`/`.dropDestination()`
  (iOS 16+). **Confirmed safe on this branch** — the project's actual floor is
  already iOS 16.0 (see §3 correction), so this is not gated behind a future bump.
- **Why it avoids the failure:** Apple's own gesture stack replaces the
  hand-rolled `LongPressGesture.sequenced(before: DragGesture())`; still SwiftUI-
  native (no `UIViewRepresentable` bridge needed) if the team wants to stay in one
  framework. Must still respect pitfall #1/#3 from §3 — keep each section's drop
  targets in their own small, non-nested container (e.g. a fixed-height `HStack`,
  not another `ScrollView`), which the current preview layout already does for
  Column 1/2 (fixed 3-row `VStack`) and would need for the Top Row's horizontal
  `ScrollView` strip specifically (that one scrollable strip is the closest
  analog to the original failure's container shape, so it's the one part of this
  option that needs the most on-device verification).
- **Effort:** Medium (4–6 days): similar shape to Option A but with `.draggable`/
  `.dropDestination` instead of `List.onMove`; extra care/testing needed for the
  Top Row's horizontal scroll strip specifically.
- **Risk:** **Medium.** Newest API of the three, least field-mileage industry-wide,
  and the one section (Top Row) that most resembles the original failure's
  container shape (draggable cells inside a horizontal `ScrollView`) needs
  deliberate on-device verification before shipping — same caution class that
  caused the original bug, just with Apple's gesture implementation instead of a
  hand-rolled one.

---

## 5. Recommendation

**Ship Option A (per-section `List` + `.onMove`) first.** It is the lowest-risk,
lowest-effort path to real drag-and-drop reordering, it reuses Apple's single most
road-tested reorder mechanism (no custom gesture code at all — the exact category
of thing that broke last time), and it is a strict, additive extension of the
current v2 model rather than a new one: sections stay separate small lists, the
fixed numpad/🌐/digits stay structurally outside the editable model, and the
existing secure-field type-in-a-character flow is untouched (drag reorders *typed*
keys; it doesn't replace how a key's character gets set). **Risk: Low.**

If the "springboard feel" (grid drag with lift/scale, not a table row with a `≡`
handle) is important to the owner beyond function, layer in **Option B**
(`UICollectionView` drag delegate) for the Top Row specifically, since this
codebase already has a proven, on-device-verified sibling of that exact API
(`UITableViewDragDelegate` in the iPad clipboard/snippets overlays). **Risk:
Low–Medium.**

Treat **Option C** (`.draggable`/`.dropDestination`) as a future SwiftUI-native
upgrade once the team wants to drop the `UIViewRepresentable` bridge entirely — it's
viable today (the branch is already iOS 16+), but it's the newest API with the
least mileage and the Top Row's horizontal-scroll-strip case needs the most
deliberate device testing before shipping, since it's the closest surviving analog
to the original failure's container shape. **Risk: Medium.**

---

## Sources (web research)

- [SwiftUI Drag & Drop for Reordering: LazyGrid, UICollectionView & Best Practices](https://copyprogramming.com/howto/uicollectionview-with-swiftui-drag-and-drop-reordering-possible)
- [Reorder items with Drag and Drop using SwiftUI (Canopas)](https://canopas.com/reorder-items-with-drag-and-drop-using-swiftui-e336d44b9d02)
- [How to Drag & Reorder CollectionView Cells (swiftlogic.io)](https://swiftlogic.io/posts/drag-and-drop/)
- [Drag, Drop & Reorder Collection View Cells (HackerNoon)](https://medium.com/hackernoon/how-to-drag-drop-uicollectionview-cells-by-utilizing-dropdelegate-and-dragdelegate-6e3512327202)
- [Reorder cells in UICollectionView using drag & drop (HackerNoon)](https://hackernoon.com/swift-reorder-cells-in-uicollectionview-using-drag-drop-ff7eb5131052)
- [DragDropCollectionView — springboard-style wiggle reorder (GitHub)](https://github.com/Lior539/DragDropCollectionView)
- [Adopting drag and drop using SwiftUI (Apple Developer Documentation)](https://developer.apple.com/documentation/SwiftUI/Adopting-drag-and-drop-using-SwiftUI)
- [How to support drag and drop in SwiftUI (Hacking with Swift)](https://www.hackingwithswift.com/quick-start/swiftui/how-to-support-drag-and-drop-in-swiftui)
- [How to Reorder List rows in SwiftUI List (sarunw.com)](https://sarunw.com/posts/swiftui-list-onmove/)
- [How to let users move rows in a list (Hacking with Swift)](https://www.hackingwithswift.com/quick-start/swiftui/how-to-let-users-move-rows-in-a-list)
- [SwiftUI, List items reordering issue iOS 16 (Apple Developer Forums)](https://developer.apple.com/forums/thread/714612)
- [Preventing Scroll Hijacking by DragGestureRecognizer Inside ScrollView](https://darjeelingsteve.com/articles/Preventing-Scroll-Hijacking-by-DragGestureRecognizer-Inside-ScrollView.html)
- [Using complex gestures in a SwiftUI ScrollView (danielsaidi.com)](https://danielsaidi.com/blog/2022/11/16/using-complex-gestures-in-a-scroll-view)
- [Adding a drag gesture to a View inside a ScrollView blocks scrolling (Apple Developer Forums)](https://developer.apple.com/forums/thread/122083)

## Internal evidence (this repo)

- `docs/plans/2026-06-24-custom-keyboard-v2-design.md` — on-device failure findings + as-built notes
- `docs/plans/2026-06-21-customizable-keyboard-design.md` — original Phase-5 data model/editor design
- Deleted commits: `f27e435f`, `6d89e7bb`, `2cab1f67` (build), `eecd9798` (deletion, with rationale in the commit message)
- Deleted source recovered via `git show <commit>:<path>`: `SpringboardGridView.swift`, `SpringboardLayout.swift`, `KeyboardLayoutItems.swift`, `LayoutGridEditorView.swift`, `CustomKeyboardCoordinator.swift`, `SpringboardLayoutTests.swift`
- Current editor read directly: `NumPad/Libraries/CustomKeyboard/CustomKeyboardEditorView.swift`, `CustomKeyboardEditorModel.swift`, `NumPad/Controllers/CustomKeyboardEditorViewController.swift`
- Existing proven UIKit drag precedent in this codebase: `Keyboard/Views/ClipboardHistoryView.swift`, `Keyboard/Views/SnippetsListView.swift` (`UITableViewDragDelegate.itemsForBeginning`)
- Deployment-target correction: `Podfile` (`platform :ios, '16.0'`), `NumPad.xcodeproj/project.pbxproj` (`IPHONEOS_DEPLOYMENT_TARGET = 16.0`), commit `eaa49246`
