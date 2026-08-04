# NumPad 2.1 Emoji Keyboard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement
> this plan task-by-task. Every behavior task follows RED → GREEN → full touched-suite check →
> atomic commit.

**Goal:** Ship a lazy, native emoji mode inside QWERTY with deterministic search, 48-entry
recents, RGI skin-tone variants, bounded extension memory, and a first-class VoiceOver contract.

**Architecture:** Pure shared Swift types own catalog decoding, search ranking, reducer state,
and recents. `QwertyPageHost` lazily creates an extension-owned resource loader and
`EmojiKeyboardView`; search reuses `QwertyKeyboardView` as internal query input. Generated
Unicode/CLDR JSON resources are committed and loaded in two stages.

**Tech stack:** Swift 5, UIKit, XCTest, `JSONDecoder`, app-group `UserDefaults`, Unicode Emoji
14.0, CLDR 40, Xcode workspace tests.

## Global Constraints

- Deployment floor is iOS/iPadOS 16.0.
- Emoji remains nested in `QwertyPageHost`; do not add or persist a top-level `Page`.
- V1 is search + 48-entry recents + fully-qualified RGI skin-tone variants only.
- No third-party picker, `UITextField`, `UISearchBar`, runtime network, bitmap atlas, or
  analytics.
- Do not edit `QwertySpellChecker.swift`, `QwertyAutocorrect.swift`, or suggestion-coalescing
  code. No Glide and no speed claim.
- The smiley must have at least a 44 pt frame on the 320 pt reference canvas and every row must
  still total 10 units.
- Browse/search resources are each at most 1 MiB. Physical-device retained deltas are at most
  4 MiB browse and 8 MiB browse+search; parse peak is at most 10 MiB.
- Never run concurrent `xcodebuild` jobs across repositories. Scoped tests are development
  loops only; final evidence is the full `NumPadTests` package at exact `HEAD`.

---

## File map

| File | Responsibility |
|---|---|
| `tools/make_emoji_catalog.swift` | Deterministic Unicode/CLDR input parser and JSON generator |
| `scripts/add_resources.rb` | Idempotently register bundle resources with named Xcode targets |
| `Keyboard/Resources/emoji_browse_v14.json` | Ordered RGI sequences, category, variant indices |
| `Keyboard/Resources/emoji_search_en_cldr40.json` | English TTS names and keywords by catalog index |
| `Keyboard/Resources/emoji-unicode-license.txt` | License shipped with generated data |
| `Keyboard/Resources/EMOJI_PROVENANCE.md` | Source URLs, versions, input hashes, generation command |
| `NumPad/Libraries/Qwerty/EmojiCatalog.swift` | Pure payload models, validation, category mapping |
| `NumPad/Libraries/Qwerty/EmojiSearch.swift` | Normalization and deterministic ranked index results |
| `NumPad/Libraries/Qwerty/EmojiKeyboardReducer.swift` | Pure modes, actions, and host effects |
| `NumPad/Libraries/Qwerty/EmojiRecents.swift` | 48-entry MRU plus app-group persistence adapter |
| `Keyboard/Libraries/EmojiResourceLoader.swift` | Lazy bundle loading, cache, memory-warning teardown |
| `Keyboard/Views/EmojiKeyboardView.swift` | Browse collection, categories, toolbar, empty states |
| `Keyboard/Views/EmojiSearchHeaderView.swift` | Query label/value and accessible empty/no-result state |
| `Keyboard/Views/EmojiModifierChooserView.swift` | In-bounds strip/grid for RGI variants |
| `NumPad/Libraries/Qwerty/QwertyKey.swift` | Smiley and emoji-result key kinds |
| `NumPad/Libraries/Qwerty/QwertyLayout.swift` | Smiley placement and bottom-row widths |
| `Keyboard/Views/QwertyKeyboardView.swift` | Glyph rendering/labels and search-mode cursor disable |
| `Keyboard/Libraries/QwertyPageHost.swift` | Mode ownership, effect routing, lazy view/loader wiring |
| `Keyboard/KeyboardViewController.swift` | Memory-warning forwarding only |
| `NumPad/Libraries/SharedExtensions.swift` | `Constants.qwertyEmojiRecents` key |
| `NumPadTests/Emoji*Tests.swift` | Pure, view, lazy-load, accessibility, and error contracts |

### Design coverage

| Approved lock | Implemented by |
|---|---|
| 1. dedicated nested access | Tasks 4 and 6 |
| 2. pinned data + internal search | Tasks 1, 2, and 6 |
| 3. 48-entry recents | Tasks 3 and 6 |
| 4. RGI modifiers | Tasks 1 and 5 |
| 5. lazy memory budgets | Tasks 1, 6, and 7 |
| 6. VoiceOver/focus | Tasks 4, 5, 6, and 7 |
| Failure and evidence boundaries | Tasks 1–3, 6, and 7 |

## Task 1: Pinned catalog generator and decoder

**Files:**
- Create: `tools/make_emoji_catalog.swift`
- Create: `scripts/add_resources.rb`
- Create: `Keyboard/Resources/emoji_browse_v14.json`
- Create: `Keyboard/Resources/emoji_search_en_cldr40.json`
- Create: `Keyboard/Resources/emoji-unicode-license.txt`
- Create: `Keyboard/Resources/EMOJI_PROVENANCE.md`
- Create: `NumPad/Libraries/Qwerty/EmojiCatalog.swift`
- Create: `NumPadTests/EmojiCatalogTests.swift`
- Modify: `NumPad.xcodeproj/project.pbxproj`

**Interfaces:**

```swift
enum EmojiCategory: String, CaseIterable, Codable { case smileys, people, animals, food, travel, activities, objects, symbols, flags }
struct EmojiCatalogEntry: Codable, Equatable { let sequence: String; let category: EmojiCategory; let variantIndices: [Int] }
struct EmojiBrowsePayload: Codable, Equatable { let unicodeVersion: String; let entries: [EmojiCatalogEntry] }
struct EmojiCatalog: Equatable {
    let unicodeVersion: String
    let entries: [EmojiCatalogEntry]
    init(data: Data) throws
    func contains(sequence: String) -> Bool
}
```

- [ ] Add RED fixtures proving fully-qualified-only filtering, CLDR order, category mapping,
  base/variant indices, malformed-index rejection, and exact-sequence membership.
- [ ] Run `EmojiCatalogTests`; confirm failure because the types do not exist.
- [ ] Implement the generator and decoder. Pin Emoji 14.0 + CLDR 40, record SHA-256 hashes and
  exact source URLs, copy the Unicode license, and reject duplicate sequences/out-of-range
  variant indices.
- [ ] Run the generator twice into separate `/private/tmp` directories and compare both JSON
  files byte-for-byte. Assert each generated resource is no larger than 1,048,576 bytes.
- [ ] Implement `scripts/add_resources.rb <target>[,<target>] <path>...` with `xcodeproj`: reject
  unknown targets/missing paths, reuse one PBX file reference per real path, add each reference
  to each target's `resources_build_phase` exactly once, and preserve on-disk group nesting.
- [ ] Register the shared source, test, JSON files, and license exactly once:

```bash
ruby scripts/add_sources.rb NumPad,Keyboard NumPad/Libraries/Qwerty/EmojiCatalog.swift
ruby scripts/add_sources.rb NumPadTests NumPadTests/EmojiCatalogTests.swift
ruby scripts/add_resources.rb NumPad,Keyboard \
  Keyboard/Resources/emoji_browse_v14.json \
  Keyboard/Resources/emoji_search_en_cldr40.json \
  Keyboard/Resources/emoji-unicode-license.txt
```
- [ ] Run:

```bash
xcodebuild test -workspace NumPad.xcworkspace -scheme NumPad \
  -destination 'platform=iOS Simulator,id=963700AB-C3AC-447A-9EF7-CE89915E4A85' \
  -parallel-testing-enabled NO -derivedDataPath /private/tmp/NumPadEmojiDerivedData \
  -only-testing:NumPadTests/EmojiCatalogTests CODE_SIGNING_ALLOWED=NO
```

- [ ] Commit `feat: add pinned emoji catalog` with the required human trailers.

## Task 2: Deterministic search and pure reducer

**Files:**
- Create: `NumPad/Libraries/Qwerty/EmojiSearch.swift`
- Create: `NumPad/Libraries/Qwerty/EmojiKeyboardReducer.swift`
- Create: `NumPadTests/EmojiSearchTests.swift`
- Create: `NumPadTests/EmojiKeyboardReducerTests.swift`
- Modify: `NumPad.xcodeproj/project.pbxproj`

**Interfaces:**

```swift
struct EmojiSearchAnnotation: Codable, Equatable { let catalogIndex: Int; let name: String; let keywords: [String] }
struct EmojiSearchPayload: Codable, Equatable { let cldrVersion: String; let locale: String; let annotations: [EmojiSearchAnnotation] }
struct EmojiSearchIndex {
    init(data: Data, catalogCount: Int) throws
    func results(for query: String, limit: Int = 10) -> [Int]
}
enum EmojiKeyboardMode: Equatable { case typing; case browse(category: EmojiCategory, filter: String?); case search(query: String) }
enum EmojiKeyboardAction: Equatable { case openEmoji, openSearch, queryText(String), queryBackspace, queryReturn, showBrowse, selectEmoji(String), browseBackspace, showTyping, nextKeyboard, catalogFailed, searchFailed }
enum EmojiKeyboardEffect: Equatable { case loadBrowse, loadSearch, insertEmoji(String), deleteBackward, advanceToNextKeyboard, announceUnavailable, refreshTypingIfPublic }
enum EmojiKeyboardReducer { static func reduce(mode: inout EmojiKeyboardMode, action: EmojiKeyboardAction) -> [EmojiKeyboardEffect] }
```

- [ ] Add RED tests for case/width/diacritic normalization, exact-name → token-prefix → keyword
  ranking, CLDR-order ties, ten-result bound, invalid catalog indices, and English payload
  fallback selection.
- [ ] Add the full reducer transition table as RED tests. Include negative assertions that
  query text, empty-query backspace, and Return never emit `insertEmoji`. Run the command below
  and confirm the missing search/reducer types make it fail.
- [ ] Implement the minimal index and reducer. Use `en_US_POSIX` for deterministic folding;
  Return transitions to filtered browse; `showTyping` clears filter/query.
- [ ] Register the four new Swift files:

```bash
ruby scripts/add_sources.rb NumPad,Keyboard \
  NumPad/Libraries/Qwerty/EmojiSearch.swift \
  NumPad/Libraries/Qwerty/EmojiKeyboardReducer.swift
ruby scripts/add_sources.rb NumPadTests \
  NumPadTests/EmojiSearchTests.swift \
  NumPadTests/EmojiKeyboardReducerTests.swift
```
- [ ] Run and confirm both suites pass:

```bash
xcodebuild test -workspace NumPad.xcworkspace -scheme NumPad \
  -destination 'platform=iOS Simulator,id=963700AB-C3AC-447A-9EF7-CE89915E4A85' \
  -parallel-testing-enabled NO -derivedDataPath /private/tmp/NumPadEmojiDerivedData \
  -only-testing:NumPadTests/EmojiSearchTests \
  -only-testing:NumPadTests/EmojiKeyboardReducerTests CODE_SIGNING_ALLOWED=NO
```
- [ ] Commit `feat: add emoji search reducer` with required trailers.

## Task 3: Bounded recents and persistence

**Files:**
- Create: `NumPad/Libraries/Qwerty/EmojiRecents.swift`
- Create: `NumPadTests/EmojiRecentsTests.swift`
- Modify: `NumPad/Libraries/SharedExtensions.swift:121-235`
- Modify: `NumPad.xcodeproj/project.pbxproj`

**Interfaces:**

```swift
struct EmojiRecents: Equatable {
    static let capacity = 48
    private(set) var sequences: [String]
    init(raw: [String], isValid: (String) -> Bool)
    mutating func record(_ sequence: String, isValid: (String) -> Bool)
}
struct EmojiRecentsStore {
    init(defaults: UserDefaults = .group, key: String = Constants.qwertyEmojiRecents.rawValue)
    func load(isValid: (String) -> Bool) -> EmojiRecents
    func save(_ recents: EmojiRecents)
}
```

- [ ] Add RED tests for move-to-front deduplication, exact variant preservation, 48-entry trim,
  malformed/unknown filtering, corrupt-defaults fallback, and no timestamp/analytics fields.
  Run the command below and confirm failure because the recents types/key do not exist.
- [ ] Add `Constants.qwertyEmojiRecents`, then implement pure MRU and defaults adapter.
- [ ] Register the shared source and test:

```bash
ruby scripts/add_sources.rb NumPad,Keyboard NumPad/Libraries/Qwerty/EmojiRecents.swift
ruby scripts/add_sources.rb NumPadTests NumPadTests/EmojiRecentsTests.swift
```
- [ ] Run and confirm both suites pass:

```bash
xcodebuild test -workspace NumPad.xcworkspace -scheme NumPad \
  -destination 'platform=iOS Simulator,id=963700AB-C3AC-447A-9EF7-CE89915E4A85' \
  -parallel-testing-enabled NO -derivedDataPath /private/tmp/NumPadEmojiDerivedData \
  -only-testing:NumPadTests/EmojiRecentsTests \
  -only-testing:NumPadTests/QwertyPreferencesTests CODE_SIGNING_ALLOWED=NO
```
- [ ] Commit `feat: persist bounded emoji recents` with required trailers.

## Task 4: Smiley key and geometry

**Files:**
- Modify: `NumPad/Libraries/Qwerty/QwertyKey.swift:5-50`
- Modify: `NumPad/Libraries/Qwerty/QwertyLayout.swift:26-154`
- Modify: `Keyboard/Views/QwertyKeyButton.swift:14-23`
- Modify: `Keyboard/Views/QwertyKeyboardView.swift:800-840`
- Modify: `Keyboard/Libraries/QwertyPageHost.swift:1108-1230,1241-1315`
- Modify: `NumPad/Libraries/StudioKeyboardPreviewModel.swift:339-355`
- Modify: `NumPadTests/QwertyLayoutTests.swift:54-138`
- Modify: `NumPadTests/QwertyLayoutGeometryTests.swift`
- Modify: `NumPadTests/StudioKeyboardPreviewTests.swift`

**Interfaces:** add `QwertyKeyKind.emojiMode` and
`QwertyKeyKind.emojiResult(sequence: String, accessibilityLabel: String)`.

- [ ] Add RED tests asserting smiley placement after globe/layer switch across all layer,
  punctuation, globe, and dismiss combinations; exact 10-unit row sums; and a ≥44 pt smiley
  frame from `QwertyLayoutGeometry.layout` at 320 pt width.
- [ ] Add rendering RED tests for smiley/result glyphs, localized labels, and selected state.
  Run the command below and confirm failure on the missing key kinds/geometry.
- [ ] Rebalance only space/return/control widths, keeping the smiley wide enough for the 44 pt
  geometry gate. Do not change letter rows 1–3 or symbol content rows.
- [ ] Make both new key kinds exhaustive in `QwertyKeyButton`, `QwertyKeyboardView`,
  `QwertyPageHost`, and the Studio preview. At this geometry-only checkpoint the host cases are
  explicit no-ops; Task 6 replaces them with reducer effects before the feature can land.
- [ ] Run and confirm the three geometry/routing suites pass:

```bash
xcodebuild test -workspace NumPad.xcworkspace -scheme NumPad \
  -destination 'platform=iOS Simulator,id=963700AB-C3AC-447A-9EF7-CE89915E4A85' \
  -parallel-testing-enabled NO -derivedDataPath /private/tmp/NumPadEmojiDerivedData \
  -only-testing:NumPadTests/QwertyLayoutTests \
  -only-testing:NumPadTests/QwertyLayoutGeometryTests \
  -only-testing:NumPadTests/QwertyKeyboardViewHitTestTests \
  -only-testing:NumPadTests/StudioKeyboardPreviewTests CODE_SIGNING_ALLOWED=NO
```
- [ ] Commit `feat: add qwerty emoji access key` with required trailers.

## Task 5: Browse grid, modifier chooser, and accessibility

**Files:**
- Create: `Keyboard/Views/EmojiKeyboardView.swift`
- Create: `Keyboard/Views/EmojiSearchHeaderView.swift`
- Create: `Keyboard/Views/EmojiModifierChooserView.swift`
- Create: `NumPadTests/EmojiKeyboardViewTests.swift`
- Create: `NumPadTests/EmojiModifierChooserTests.swift`
- Modify: `NumPad.xcodeproj/project.pbxproj`

**Interfaces:**

```swift
@MainActor protocol EmojiKeyboardViewDelegate: AnyObject {
    func emojiKeyboardViewDidRequestTyping(_ view: EmojiKeyboardView)
    func emojiKeyboardViewDidRequestSearch(_ view: EmojiKeyboardView)
    func emojiKeyboardViewDidRequestNextKeyboard(_ view: EmojiKeyboardView)
    func emojiKeyboardViewDidRequestDelete(_ view: EmojiKeyboardView)
    func emojiKeyboardView(_ view: EmojiKeyboardView, didSelect sequence: String)
    func emojiKeyboardView(_ view: EmojiKeyboardView, didCreateGlobe button: UIButton)
}
```

- [ ] Add RED view tests for Recents/Smileys initial category, filtered empty state, toolbar
  actions, reusable cells, CLDR labels/traits, selected category state, deterministic traversal,
  and `.layoutChanged` focus targets.
- [ ] Add RED chooser tests for horizontal/grid selection, exact sequence callbacks, outside-tap
  dismissal, VoiceOver custom action, and containment at phone 320 pt, iPad standard, Split View,
  and floating widths. Run the command below and confirm failure because both view types are
  absent.
- [ ] Implement the collection view, search header, and bounded child chooser using text
  glyphs/system symbols only. Browse owns a bounded backspace-repeat timer using
  `QwertyBackspacePolicy`; the globe callback lets `QwertyPageHost` attach both advance-on-tap
  and `handleInputModeList`. Do not create a window-level or `UIPopoverPresentationController`
  path.
- [ ] Register all three views with `NumPad,Keyboard` and the tests with `NumPadTests`:

```bash
ruby scripts/add_sources.rb NumPad,Keyboard \
  Keyboard/Views/EmojiKeyboardView.swift \
  Keyboard/Views/EmojiSearchHeaderView.swift \
  Keyboard/Views/EmojiModifierChooserView.swift
ruby scripts/add_sources.rb NumPadTests \
  NumPadTests/EmojiKeyboardViewTests.swift \
  NumPadTests/EmojiModifierChooserTests.swift
```

- [ ] Run:

```bash
xcodebuild test -workspace NumPad.xcworkspace -scheme NumPad \
  -destination 'platform=iOS Simulator,id=963700AB-C3AC-447A-9EF7-CE89915E4A85' \
  -parallel-testing-enabled NO -derivedDataPath /private/tmp/NumPadEmojiDerivedData \
  -only-testing:NumPadTests/EmojiKeyboardViewTests \
  -only-testing:NumPadTests/EmojiModifierChooserTests \
  -only-testing:NumPadTests/QwertyThemePaletteTests CODE_SIGNING_ALLOWED=NO
```
- [ ] Commit `feat: build accessible emoji browser` with required trailers.

## Task 6: Lazy resources and page-host integration

**Files:**
- Create: `Keyboard/Libraries/EmojiResourceLoader.swift`
- Create: `NumPadTests/EmojiResourceLoaderTests.swift`
- Create: `NumPadTests/EmojiPageHostSourceContractTests.swift`
- Modify: `Keyboard/Libraries/QwertyPageHost.swift:19-390,933-1380`
- Modify: `Keyboard/Views/QwertyKeyboardView.swift:130-220,796-840`
- Modify: `Keyboard/KeyboardViewController.swift:20-35,1365-1405`
- Modify: `NumPad.xcodeproj/project.pbxproj`

**Interfaces:**

```swift
protocol EmojiResourceLoading: AnyObject {
    var hasLoadedBrowse: Bool { get }
    var hasLoadedSearch: Bool { get }
    func loadBrowse() async throws -> EmojiCatalog
    func loadEnglishSearch(catalogCount: Int) async throws -> EmojiSearchIndex
    func handleMemoryWarning(isEmojiActive: Bool)
}
```

- [ ] Register the loader and both tests:

```bash
ruby scripts/add_sources.rb NumPad,Keyboard Keyboard/Libraries/EmojiResourceLoader.swift
ruby scripts/add_sources.rb NumPadTests \
  NumPadTests/EmojiResourceLoaderTests.swift \
  NumPadTests/EmojiPageHostSourceContractTests.swift
```

- [ ] Add RED loader tests proving zero factory invocation during ordinary QWERTY setup,
  browse-only first load, search-only second load, cache reuse, buffer release, missing-resource
  errors, and active/inactive memory-warning teardown.
- [ ] Add RED host source-contract tests for smiley → browse, internal query routing,
  result insertion + MRU, Return-filters-only, browse deletion, globe/`ABC`, search-mode cursor
  disable, catalog failure announcement, and English-search failure state. Run the command below
  and confirm it fails on the missing loader and host wiring.
- [ ] Store an `emojiLoaderFactory` closure in `QwertyPageHost` but instantiate neither loader
  nor view until `.loadBrowse`. Route reducer effects on `@MainActor`; perform bundle file read
  and JSON decode off main, returning immutable values.
- [ ] In browse mode, the emoji view fills `containerView`. In search mode, hide the ordinary
  suggestion bar, pin `EmojiSearchHeaderView` to its 44 pt slot, and show QWERTY rows beneath it
  with emoji results in the top strip. Restoring typing hides both emoji views and restores the
  existing suggestion-bar/keyboard constraints without rebuilding the host.
- [ ] On emoji exit, use only an existing public host refresh boundary; if none exists, emit no
  forced refresh and let the next ordinary key refresh naturally. Do not edit frozen files.
- [ ] Forward `KeyboardViewController.didReceiveMemoryWarning()` to
  `QwertyPageHost.handleMemoryWarning()`; dismiss chooser and release caches per the design.
- [ ] Run the integration regression set and confirm it passes:

```bash
xcodebuild test -workspace NumPad.xcworkspace -scheme NumPad \
  -destination 'platform=iOS Simulator,id=963700AB-C3AC-447A-9EF7-CE89915E4A85' \
  -parallel-testing-enabled NO -derivedDataPath /private/tmp/NumPadEmojiDerivedData \
  -only-testing:NumPadTests/EmojiCatalogTests \
  -only-testing:NumPadTests/EmojiSearchTests \
  -only-testing:NumPadTests/EmojiKeyboardReducerTests \
  -only-testing:NumPadTests/EmojiRecentsTests \
  -only-testing:NumPadTests/EmojiKeyboardViewTests \
  -only-testing:NumPadTests/EmojiModifierChooserTests \
  -only-testing:NumPadTests/EmojiResourceLoaderTests \
  -only-testing:NumPadTests/EmojiPageHostSourceContractTests \
  -only-testing:NumPadTests/QwertyLayoutTests \
  -only-testing:NumPadTests/QwertyLayoutGeometryTests \
  -only-testing:NumPadTests/QwertyKeyboardViewHitTestTests \
  -only-testing:NumPadTests/QwertyGatingTests \
  -only-testing:NumPadTests/KioskSessionPolicyTests CODE_SIGNING_ALLOWED=NO
```
- [ ] Commit `feat: integrate lazy emoji mode` with required trailers.

## Task 7: Localization, full certification, and handoff

**Files:**
- Modify: all 16 `Keyboard/*.lproj/Localizable.strings` files for new UI and VoiceOver keys
- Modify: all 16 `NumPad/*.lproj/Localizable.strings` files so app-target view tests resolve the
  same keys
- Create: `NumPadTests/EmojiLocalizationTests.swift`
- Modify: `NumPad.xcodeproj/project.pbxproj`
- Create: `docs/release/2026-08-04-emoji-verification.md`

- [ ] Add the exact new keys to English and all 15 other current locale tables in both targets.
  V1 search annotations fall back to English; UI and accessibility chrome must not fall back
  silently.
- [ ] Add `EmojiLocalizationTests` that enumerates both `Keyboard` and `NumPad` localization
  directories, asserts exactly 16 tables per target, parses every table, and checks non-empty
  values plus format-token parity for every emoji UI/accessibility key.
- [ ] Register the localization test:

```bash
ruby scripts/add_sources.rb NumPadTests NumPadTests/EmojiLocalizationTests.swift
```

- [ ] Run:

```bash
xcodebuild test -workspace NumPad.xcworkspace -scheme NumPad \
  -destination 'platform=iOS Simulator,id=963700AB-C3AC-447A-9EF7-CE89915E4A85' \
  -parallel-testing-enabled NO -derivedDataPath /private/tmp/NumPadEmojiDerivedData \
  -only-testing:NumPadTests/EmojiLocalizationTests \
  -only-testing:NumPadTests/EmojiCatalogTests \
  -only-testing:NumPadTests/EmojiSearchTests \
  -only-testing:NumPadTests/EmojiKeyboardReducerTests \
  -only-testing:NumPadTests/EmojiRecentsTests \
  -only-testing:NumPadTests/EmojiKeyboardViewTests \
  -only-testing:NumPadTests/EmojiModifierChooserTests \
  -only-testing:NumPadTests/EmojiResourceLoaderTests \
  -only-testing:NumPadTests/EmojiPageHostSourceContractTests CODE_SIGNING_ALLOWED=NO
```
- [ ] Self-review the complete branch against every section of
  `2026-08-04-emoji-design.md`; scan for debug code, frozen-file diffs, Glide changes, unbounded
  caches, third-party/runtime-network paths, and accidental `Page` changes.
- [ ] Create a fresh result directory and run the full package once, with no concurrent build:

```bash
NUMPAD_EMOJI_RESULT_DIR=$(mktemp -d /private/tmp/numpad-emoji-results.XXXXXX)
xcodebuild test -workspace NumPad.xcworkspace -scheme NumPad \
  -destination 'platform=iOS Simulator,id=963700AB-C3AC-447A-9EF7-CE89915E4A85' \
  -parallel-testing-enabled NO -derivedDataPath /private/tmp/NumPadEmojiDerivedData \
  -resultBundlePath "$NUMPAD_EMOJI_RESULT_DIR/Full-NumPadTests.xcresult" \
  CODE_SIGNING_ALLOWED=NO
```

- [ ] In the same shell, record `git rev-parse HEAD`, parse xcresult totals/failure names, and
  write the exact simulator result plus the still-open physical iPhone/iPad gates to the
  verification note. Do not convert simulator memory or VoiceOver checks into certification.
- [ ] Commit `test: certify emoji integration` with required trailers.
- [ ] Request Cursor land review with exact SHA, full xcresult path/counts/failure names, diff
  summary, resource byte sizes, and explicit physical-device exclusions.

## Completion rule

Engineering is ready to land only when all commits above are self-reviewed and the full package
result is attributed to the same exact `HEAD`. The 2.1 emoji release gate remains open until the
oldest available iPhone and iPad complete the real-host, memory, bounds, and manual VoiceOver
matrix in the design.
