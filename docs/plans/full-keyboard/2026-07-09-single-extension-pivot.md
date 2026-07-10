# NumPad Type — Single-Extension Pivot (owner decision, 2026-07-09)

## Decision

The full-QWERTY keyboard ships **inside the existing `Keyboard` (numpad) extension as a
second page**, not as the separate `KeyboardType` extension the original plan built. The
`KeyboardType` target is deleted.

Owner feedback that drove this (testing notes, 2026-07-09):

1. *"Is it required that we have a separate keyboard listed in iOS settings? It seems like we
   should piggyback off of the permissions we currently have."* — iOS cannot share enablement
   or Full Access between two extensions (each is its own Settings entry + permission grant),
   so the only way to piggyback is one extension with two pages. Existing users' enablement
   and Full Access now carry over to the QWERTY page automatically.
2. The QWERTY's numpad must be **the existing numpad, identical to the current build** — as a
   page of the same keyboard. The internal `QwertyNumpadLayer` flip canvas (and its strip
   auto-swap) is removed; the flip key ("NumPad") now switches to the real numpad page, and an
   "ABC" key (accessibility label "Letters") on the numpad's bottom row switches back.
3. QWERTY visuals must match the numpad's visual language (theme colors/flat keys), not the
   Android-like styling of the first pass.
4. No touch dead zones: every point on the QWERTY page maps to a key
   (`QwertyTouchRouting.keyIndex` — direct hits always win; gaps resolve by nearest edge with
   a capped bias toward the likely next key, derived from the completions the suggestion bar
   already fetches, so the prediction costs nothing extra).
5. iOS-parity tertiary symbols layer: letters → "123" → numbers → "#+=" → symbols.

## Architecture after the pivot

- `KeyboardViewController` hosts two pages: `.numpad` (existing behavior, byte-for-byte when
  the feature is off) and `.qwerty` (`Keyboard/Libraries/QwertyPageHost.swift`, the port of
  the deleted `QwertyKeyboardViewController`). Last-used page persists in the app group.
- Gate for the QWERTY page (ABC key visibility + page restore):
  `FeatureFlags.isQwertyPageAvailable` = the `full_keyboard_enabled` RC kill switch + Pro
  entitlement — the standalone extension's exact rule. The local `fullKeyboardEnabled` flag
  gates app-side surfacing (the Home row) only; requiring it in the page gate briefly made the
  keyboard unreachable on devices that could previously type on the standalone extension
  (owner-reported, fixed same day).
- Pure logic stays in `NumPad/Libraries/Qwerty/` (now compiled into app + Keyboard targets).
  Views live in `Keyboard/Views/` (moved from `KeyboardType/Views/`).
- Enablement UX: the setup wizard's "Enable in Settings" now reflects the single NumPad
  keyboard (`Keyboard.isKeyboardEnabled`); no second Add-New-Keyboard step exists anymore.
- E2E: `QwertyTypeSmokeTests` drives the page switch with in-keyboard taps (ABC ⇄ NumPad) —
  the iPadOS keyboard-switcher automation gap that blocked the two-extension E2E is gone by
  construction. A new DEBUG route `numpad://debug/fullkeyboard?enabled=1|0` (and its
  `-debugRoute` launch-arg form) sets the local rollout flag for tests.

## Follow-ups (owner notes 2026-07-10)

- **QWERTY-native strip rows — plan more options.** Two shipped (Punctuation: writing/texting
  marks; Snippets: the user's snippets as one-tap strip keys, tokens expanded at tap time),
  deliberately capped at two so strip navigation stays manageable. Candidates to evaluate
  later: emoji shortcut row, clipboard-history row, markdown row, contextual row driven by
  the host field type, per-user pinned/custom QWERTY row (Custom Pack crossover already
  exists). Decide together with whether the numeric crossover packs should stay in the
  QWERTY family at all once native rows cover prose needs.
- Glide typing + priority dictionaries: see `research/2026-07-10-glide-typing.md` and
  `research/2026-07-10-priority-dictionaries-and-key-accuracy.md`.
- Lock-chip upsell on the ABC key for unentitled users; ABC on the Custom Keyboard layout
  shipped 2026-07-10.

## Superseded from the original plan

- §"second extension" architecture, its per-extension locked overlay
  (`QwertyLockedOverlayView`), and the per-keyboard Settings enablement flow.
- The numpad-canvas strip auto-swap (digits-shown-twice can no longer occur — the numpad page
  and the QWERTY strip never render simultaneously). `QwertyPackFamily`'s canvas-aware API
  remains only until the next cleanup pass.
- The numpad's sibling-keyboard dedicated globe key (2026-07-09 fix, commit e6c29b63): with a
  single keyboard there is no sibling to reach; the ABC/flip pair replaces it. The
  Home-button-device globe behavior is unchanged.
