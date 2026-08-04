# NumPad 2.1 Emoji Keyboard — Design

**Date:** 2026-08-04
**Status:** Approved in six locks by Cursor, acting as the owner-delegated 2.1 orchestrator.
**Scope:** 2.1.3 only — search, recents, and skin-tone modifiers inside the existing QWERTY page.

This design turns emoji into a first-class QWERTY mode without making it another persisted
keyboard page, consuming suggestion width, or introducing a second text responder inside the
extension. It is deliberately bounded for the extension's memory ceiling and for the current
iOS 16.0 deployment floor.

## Decisions at a glance

1. **Access:** a dedicated smiley key in every QWERTY bottom row, immediately after globe when
   globe is present and after the layer switch otherwise.
2. **Search data:** committed, version-pinned Unicode RGI catalog plus CLDR annotations, split
   into lazy browse and search resources. Search reuses QWERTY keys as internal query input.
3. **Recents:** 48 unique exact sequences, MRU ordered in app-group `UserDefaults`.
4. **Modifiers:** use only fully-qualified RGI variant families from the pinned catalog; never
   synthesize scalar combinations at runtime.
5. **Memory:** zero emoji allocation on ordinary QWERTY startup; browse and search load in
   separate stages under pre-registered resource and physical-device heap budgets.
6. **VoiceOver:** CLDR names, explicit control state, bounded modifier actions, and deliberate
   focus transitions are part of V1 rather than follow-up polish.

## Constraints and boundaries

- Emoji is nested under `QwertyPageHost`; it is **not** a new persisted top-level `Page`.
- No `UITextField`, `UISearchBar`, recursive first responder, third-party picker, runtime
  network request, or bitmap emoji atlas.
- No change to `QwertySpellChecker.swift`, `QwertyAutocorrect.swift`, or existing suggestion
  coalescing paths.
- No Glide work and no speed claim.
- Simulator evidence may land engineering but cannot certify extension memory, physical
  VoiceOver, or real-host behavior.

## 1. Access point and mode topology

### Bottom-row key

Every QWERTY layer gains a dedicated smiley key:

- place it immediately after globe when globe exists;
- otherwise place it immediately after the layer switch;
- keep it out of the three-slot suggestion bar;
- do not hide it behind long-press;
- expose a localized `Emoji` label and selected state while an emoji mode is active.

The smiley receives enough row units to produce a minimum **44 pt interactive frame on the
320 pt reference canvas**. Space and return absorb the width reduction. Layout tests must cover
every phone/iPad option combination, assert that each bottom row still sums to exactly 10 units,
and assert the smiley minimum target.

### Nested views

`QwertyPageHost` owns one small mode reducer and swaps between:

- the existing `QwertyKeyboardView` in ordinary typing mode;
- a lazily created `EmojiKeyboardView` for browse mode; and
- the existing QWERTY rows repurposed as internal query keys for search mode.

`EmojiKeyboardView` is a native reusable-cell collection view with an in-bounds toolbar for
category selection, `ABC`, search, globe, and host backspace. `ABC` returns to ordinary typing.
Exiting through `ABC` clears the query and filter; a later smiley entry starts clean on Recents
when non-empty, otherwise Smileys.

## 2. Catalog, annotations, and search

### Reproducible data

The shipped catalog is generated and committed. A deterministic tool under `tools/` consumes:

- Unicode Emoji 14.0 `emoji-test.txt`, using fully-qualified RGI entries in CLDR order; and
- CLDR 40 English annotations for TTS names and keywords.

Emoji 14.0 is the conservative catalog for the iOS 16.0 deployment floor. Entries from later
Unicode emoji releases remain excluded until an OS-capability table and device gate are added.
The generator records both source versions and retains the Unicode license beside the generated
resources. Re-running it from the pinned inputs must be byte-stable.

The generated representation is compact and index based. Each catalog record includes:

- exact Unicode sequence;
- Unicode group and subgroup;
- stable CLDR order;
- TTS name and keywords through a separate annotation index; and
- indices for the base emoji's fully-qualified variant family.

Browse metadata and search annotations are separate resources. Opening emoji browse must not
load the annotation resource. V1 requires English annotations as a deterministic fallback.
Locale-specific annotation resources may be added in the Wave 3 localization sweep; a missing
locale falls back to English rather than yielding an empty catalog.

### Search surface

Search does not create another responder. Entering search retains the existing QWERTY rows but
routes character, space, and backspace into the emoji reducer rather than the host document:

- the header exposes `Emoji search` and the current query;
- the top strip shows at most ten ranked emoji result glyphs;
- empty-query backspace is a no-op;
- globe keeps its existing next-keyboard behavior;
- the space-cursor gesture is disabled only while search is active;
- tapping a result inserts that exact sequence and leaves search open; and
- Return applies the query to the full browse grid and never inserts a result.

First-result-on-Return is explicitly out of V1.

Queries normalize case, width, and diacritics. Ranking is deterministic:

1. exact TTS-name match;
2. token-prefix match;
3. keyword match;
4. stable CLDR order as the tie-break.

Results and filters hold catalog indices instead of copies of catalog records. Search is not
personalized by recency in V1.

## 3. Pure state reducer and effects

UIKit renders reducer state and performs emitted effects. The reducer owns:

```swift
enum EmojiKeyboardMode: Equatable {
    case typing
    case emojiBrowse(category: EmojiCategory, filter: String?)
    case emojiSearch(query: String)
}
```

The exact implementation type may be split for testability, but these semantics are fixed:

| Input | From | To | Effect |
|---|---|---|---|
| smiley | typing | emojiBrowse | lazy-load browse |
| search | emojiBrowse | emojiSearch("") | lazy-load annotations |
| character / space | emojiSearch | emojiSearch(updated) | none |
| backspace, non-empty query | emojiSearch | emojiSearch(updated) | none |
| backspace, empty query | emojiSearch | unchanged | none |
| Return | emojiSearch | emojiBrowse(filter: query) | none |
| smiley | emojiSearch | emojiBrowse(filter: query) | none |
| glyph | browse/search | unchanged | insert exact sequence + update MRU |
| browse backspace | emojiBrowse | unchanged | delete host backward |
| ABC | emojiBrowse | typing | clear filter/query |
| globe | any emoji mode | unchanged | advance to next keyboard |

Pure tests must prove that query keys and Return cannot emit a host-insert effect.

Suggestion work pauses while the reducer is outside `typing`. Returning to typing may call only
an existing public `QwertyPageHost` refresh boundary. If implementation inspection finds no
public boundary that avoids the frozen spell-check/autocorrect/coalescing files, the transition
performs no forced refresh; the next ordinary typing event refreshes naturally.

## 4. Recents

Recents is a bounded, local MRU:

- capacity: **48 unique exact emoji sequences**;
- record only an emitted glyph insertion;
- deduplicate by moving the exact sequence to the front;
- trim to 48 after each mutation;
- persist `[String]` through `UserDefaults.group` with a new `Constants` key;
- store no timestamp and emit no analytics;
- provide no cloud sync, export, or clear-history UI in V1.

On load, discard malformed or unknown sequences against the pinned catalog. Corrupt or
unavailable defaults become an empty list. Recents is the first category only when non-empty;
otherwise the initial category is Smileys.

## 5. Skin-tone modifiers

The generator groups the exact fully-qualified RGI sequences present in the pinned Unicode
catalog. Runtime code never constructs scalar combinations.

- A normal tap inserts the base sequence.
- Long-press on a base with variants opens a reusable chooser inside
  `EmojiKeyboardView.bounds`.
- Small families use a horizontal strip; large or mixed-tone families use a compact grid.
- The chooser repositions rather than escaping the keyboard on phone, iPad standard, or iPad
  floating geometry. It never uses a host-window popover.
- Choosing a variant inserts that exact sequence and records that exact sequence in recents.
- Outside tap, successful choice, mode exit, or memory warning dismisses the chooser.
- V1 does not remember or globally apply a preferred skin tone.

Cells with variants expose a localized `Choose skin tone` VoiceOver custom action. Variant
choices use CLDR TTS names plus localized tone descriptors.

## 6. Loading and memory

### Lazy boundaries

Ordinary QWERTY startup allocates no emoji view, catalog, annotations, or index. An injectable
loader spy makes that boundary testable.

1. First smiley entry creates the collection view and loads browse metadata only.
2. First search loads English annotations on a dedicated emoji worker and applies immutable
   results on main.
3. The emoji worker does not reuse or modify the existing suggestion coalescer.

Glyphs render as text plus existing system symbols. Raw parse buffers are released after
immutable indexed records are built. Collection cells and the modifier chooser are reused.

### Pre-registered budgets

| Measure | Gate |
|---|---:|
| Browse resource | ≤ 1 MiB |
| English search resource | ≤ 1 MiB |
| Stabilized retained-heap delta after browse | ≤ 4 MiB |
| Stabilized retained-heap delta after browse + search | ≤ 8 MiB |
| Parse peak above ordinary QWERTY | ≤ 10 MiB |

Heap gates require a supported physical floor-class device and a trace labeled with exact model,
OS, and build. Simulator values are diagnostic only. A failed budget blocks the emoji release
gate and triggers compaction; the threshold is not raised after seeing the result.

On memory warning:

- dismiss the modifier chooser;
- drop annotations, search indices, and transient filters/results;
- tear down the entire emoji view/catalog when emoji is inactive; and
- while browse is active, retain only the minimum catalog needed to render and permit search
  data to reload later.

## 7. VoiceOver and focus

- Smiley, `ABC`, search, globe, backspace, and category controls use localized labels and button
  traits. Smiley and the current category expose selected state.
- Every emoji cell and result uses the CLDR TTS name. A localized variant hint appears only when
  a variant family exists.
- The search header exposes `Emoji search` as its label and the current query as its value.
- Empty and no-results states are real accessibility elements rather than visual-only text.
- Focus moves with `UIAccessibility.post(.layoutChanged, ...)`:
  - smiley entry → browse heading/current category;
  - search entry → query header;
  - Return → filtered-results heading or no-results element;
  - `ABC` → the smiley key in restored QWERTY.
- Fatal catalog failure posts one accessible unavailable announcement before restoring typing.
- Glyph insertion relies on the focused button action and host behavior; V1 adds no duplicate
  `Inserted …` announcement.
- All controls retain at least 44 pt interactive frames, deterministic traversal, sufficient
  contrast under existing themes, and unclipped accessibility frames.

## 8. Failure behavior

Failures enter the reducer and fail closed:

| Failure | Behavior |
|---|---|
| Catalog missing or invalid | Restore typing, announce emoji unavailable, no host insertion |
| Locale annotations missing | Use pinned English fallback |
| English annotations invalid | Browse remains available; search reports unavailable |
| Recents corrupt or unavailable | Start with an empty Recents list |
| Memory warning | Apply the teardown policy above; reload lazily when needed |
| Empty search result | Expose an accessible no-results element; Return inserts nothing |

There is no network retry path and no extension crash is acceptable as fallback behavior.

## 9. Verification matrix

### Pure and unit evidence

- byte-stable generator fixture and source-version/license validation;
- catalog decoding, normalization, deterministic ranking, and English fallback;
- complete reducer transition table;
- negative proof that query keys and Return never emit host insertion;
- 48-entry MRU, deduplication, catalog validation, and corruption fallback;
- RGI-only variant-family grouping and exact-sequence insertion;
- zero-load loader spy, staged-load checks, memory-warning effects, and error fallbacks.

### Geometry and integration evidence

- every bottom-row option combination sums to exactly 10 units;
- smiley target is at least 44 pt on the 320 pt reference canvas;
- phone portrait, iPad standard, Split View, and floating layout bounds;
- modifier chooser stays inside the keyboard in every geometry;
- search → filtered browse → typing focus targets;
- repeated insert, browse backspace, globe, `ABC`, and query isolation.

### Package certification

Run the full `NumPadTests` package from the exact rebased implementation tip. Preserve the
xcresult, report totals and every failure name, and verify `HEAD` in the same shell. A scoped
suite does not certify the package.

### Physical extension gate

Use the oldest available iPhone **and** iPad in real host apps. Exercise cold browse/search,
repeated insert/backspace/globe/`ABC`, modifier choice, memory trace, rotation, Split View and
floating mode where applicable, and manual VoiceOver traversal/actions. Every result names the
device, OS, host, and build.

Until both form-factor evidence exists, simulator passes may land engineering but cannot close
memory, physical VoiceOver, or host-matrix gates. Copy may not make a speed claim or imply broad
device certification.

## 10. Ownership and delivery sequence

### Owned by the emoji lane

- new `Keyboard/Views/*Emoji*` files;
- new `Keyboard/Libraries/*Emoji*` files;
- generated resources and their reproducible tool/license note;
- new emoji tests;
- this design note; and
- project-file additions required for those new sources/resources.

Before routing edits, claim `QwertyKeyboardView.swift`, `QwertyPageHost.swift`, and
`KeyboardViewController.swift`. The emoji mode should remain within `QwertyPageHost`; changing
the persisted `Page` enum is a product fork and requires owner escalation.

### Frozen

- `QwertySpellChecker.swift`;
- `QwertyAutocorrect.swift`; and
- existing suggestion coalescing paths.

### Sequence

1. Commit this markdown-only design note on `feat/2.1-emoji`.
2. Obtain Cursor's written-spec review on the exact design commit.
3. Rebase the lane onto integration tip `c254f15d` before any implementation commit.
4. Write the implementation plan.
5. Implement test-first in bounded commits.
6. Run full-package certification and request Cursor land review with the xcresult at exact tip.

## Non-goals

- Genmoji, stickers, kaomoji, GIFs, or media search;
- preferred/global skin-tone persistence;
- search personalization by recency;
- clear-recents UI, analytics, sync, or export;
- first-result insertion on Return;
- locale annotation packs beyond the required English fallback in this wave;
- runtime catalog updates or emoji newer than the iOS 16.0-compatible pinned catalog;
- a third-party picker or an embedded text responder; and
- changes to Glide, spell checking, autocorrect, or suggestion coalescing.

## Sources and approval record

- [Unicode Emoji 14.0 test data](https://unicode.org/Public/emoji/14.0/emoji-test.txt)
- [CLDR 40 English annotations](https://github.com/unicode-org/cldr-json/tree/40.0.0/cldr-json/cldr-annotations-full/annotations/en)
- [Unicode License v3](https://www.unicode.org/license.txt)
- Product scope: `2026-07-05-product-plan.md` and `2026-07-05-technical-feasibility.md`
- Access lock: Buzz event `c4f9a5e8e75d71f0cb11543747ea9fd9303e7b8ca532744ed5efee93f38810b6`
- Architecture lock: Buzz event `cfb5ed74c144e785352ecf459e2636c6b8825ce94eb636c1e12f3a25488615f4`
- Sections 1–3 approvals: Buzz events `d6bab2351f930050d5df617ab7af4c9394bcc9090ed3196d74449d35b34184ab`,
  `d1a9c3f70960aa36e28a6e8df22905a024a4aff6d309d4ab1efaaf3c51d7a5a7`, and
  `877a959b83f3348d50daa065cc06d4649e0fd832942b53e5e73a40a0a6d0dd7d`.
