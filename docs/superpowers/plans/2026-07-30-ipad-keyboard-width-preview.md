# iPad Keyboard Width and Truthful Preview Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the iPad numpad full-width by default with five horizontal width choices, replace
legacy iPad QWERTY layouts with Standard and Full Keyboard compositions, and make one permanent
bottom preview truthfully mirror the real keyboard.

**Architecture:** Add backward-compatible typed preferences and pure horizontal geometry shared by
the app and extension. Reuse the extension's existing interactive `StackView` as the side numpad in
Full Keyboard mode, and extend the model-driven Studio preview to render the same composition.
Keep the existing height resolver and height constraints as the only vertical-size owners.

**Tech Stack:** Swift, UIKit, XCTest/XCUITest, app-group `UserDefaults`, Darwin settings
notifications, CocoaPods, and `NumPad.xcworkspace`.

## Global Constraints

- Build and test `NumPad.xcworkspace`, never the `.xcodeproj`.
- The deployment target remains iOS 16.0.
- Use UIKit; do not introduce SwiftUI or a new dependency.
- Numpad width choices are exactly 60%, 70%, 80%, 90%, and 100%.
- New installations default to 100%.
- Width changes are horizontal only. Do not change `KeyboardHeightPreset`,
  `KeyboardViewController.heightConstraint`, `QwertyPageHost.baseHeight`, row-height policy,
  vertical spacing, vertical insets, kiosk height, or floating-keyboard height behavior.
- Standard iPad QWERTY is full-width and keeps the number row visible.
- Full Keyboard uses Standard QWERTY plus the real active numpad on the selected left or right.
- iPhone keyboard layout and page-switching behavior remain unchanged.
- All keyboard-affecting preferences use `UserDefaults.group`, a `Constants` key, and exactly one
  `SettingsSync.post()` per user mutation.
- Existing profile JSON must continue to decode. New profile fields are optional during decoding
  and receive deterministic legacy fallbacks.
- The keyboard extension remains within its existing memory budget; do not duplicate interactive
  numpad views or add image snapshots.
- Do not log typed, clipboard, snippet, dictionary, custom-key, or imported-profile content.
- Preserve unrelated user changes and do not read, modify, stage, or delete `Auto-Company/`.
- Use RED -> GREEN -> REFACTOR for every behavior change and record focused commands in the task
  report.
- Do not archive, upload, or submit anything to Apple.

### Binding References

- Design:
  `docs/superpowers/specs/2026-07-30-ipad-keyboard-width-preview-design.md`
- Existing extension height owner:
  `Keyboard/KeyboardViewController.swift` and `Keyboard/Libraries/QwertyPageHost.swift`
- Existing permanent dock:
  `NumPad/Controllers/Studio/IPadStudioWorkspaceViewController.swift`
- Existing preview model and renderer:
  `NumPad/Libraries/StudioKeyboardPreviewModel.swift` and
  `NumPad/Views/StudioKeyboardPreviewView.swift`

---

### Task 1: Add Backward-Compatible Width and iPad Layout Preferences

**Files:**

- Modify: `NumPad/Libraries/KeyboardLayoutPreferences.swift`
- Modify: `NumPad/Libraries/SharedExtensions.swift`
- Modify: `NumPad/Libraries/Profiles/KeyboardProfile.swift`
- Modify: `NumPad/Libraries/Profiles/KeyboardProfileFactory.swift`
- Modify: `NumPad/Libraries/Profiles/KeyboardProfileApplier.swift`
- Modify: `NumPad/Libraries/Profiles/KeyboardProfileMigration.swift`
- Modify: `NumPadTests/QwertyPreferencesTests.swift`
- Modify: `NumPadTests/KeyboardProfileTests.swift`
- Modify: `NumPadTests/KeyboardProfileApplierTests.swift`
- Modify: `NumPadTests/KeyboardProfileMigrationTests.swift`

**Interfaces:**

- Produces:
  `NumpadWidthSize`, `IPadQwertyLayout`, `FullKeyboardNumpadSide`,
  `UserPrefs.numpadWidthSize`, `UserPrefs.iPadQwertyLayout`, and
  `UserPrefs.fullKeyboardNumpadSide`.
- Produces optional profile raw fields `numpadWidthSizeRaw`, `iPadQwertyLayoutRaw`, and
  `fullKeyboardNumpadSideRaw`.
- Legacy `NumpadPlacement` and `QwertyLayoutMode` remain decodable migration inputs but are no
  longer primary user-facing settings.

- [ ] **Step 1: Write failing preference-default and legacy-normalization tests**

  Add tests that require these exact public values:

  ```swift
  XCTAssertEqual(NumpadWidthSize.allCases.map(\.fraction), [0.60, 0.70, 0.80, 0.90, 1.00])
  XCTAssertEqual(NumpadWidthSize.defaultValue, .full)
  XCTAssertEqual(IPadQwertyLayout.defaultValue, .standard)
  XCTAssertEqual(FullKeyboardNumpadSide.defaultValue, .right)
  XCTAssertEqual(NumpadWidthSize.migrated(from: .fullWidth), .full)
  XCTAssertEqual(NumpadWidthSize.migrated(from: .automatic), .compact)
  XCTAssertEqual(IPadQwertyLayout.migrated(from: .split), .standard)
  ```

  Test a temporary `UserDefaults` suite with no keys, new keys, and legacy-only keys. A fresh suite
  must resolve Full/Standard/Right. A legacy suite must resolve the migration mappings without
  altering keyboard height keys.

- [ ] **Step 2: Run the focused tests and verify RED**

  Run:

  ```bash
  xcodebuild -workspace NumPad.xcworkspace -scheme NumPad \
    -destination 'platform=iOS Simulator,id=5B976E69-A682-4406-BCFD-BCA93FC96352' \
    test -only-testing:NumPadTests/QwertyPreferencesTests
  ```

  Expected: failure because the three typed preferences and their defaults do not exist.

- [ ] **Step 3: Implement the typed preferences**

  Define:

  ```swift
  enum NumpadWidthSize: String, Codable, CaseIterable {
      case compact, comfortable, medium, wide, full
      static let defaultValue: Self = .full
      var fraction: CGFloat { [0.60, 0.70, 0.80, 0.90, 1.00][allCases.firstIndex(of: self)!] }
      static func migrated(from legacy: NumpadPlacement) -> Self {
          legacy == .fullWidth ? .full : .compact
      }
  }

  enum IPadQwertyLayout: String, Codable, CaseIterable {
      case standard, full
      static let defaultValue: Self = .standard
      static func migrated(from legacy: QwertyLayoutMode) -> Self { .standard }
  }

  enum FullKeyboardNumpadSide: String, Codable, CaseIterable {
      case left, right
      static let defaultValue: Self = .right
  }
  ```

  Implement `fraction` with an exhaustive switch in production rather than the array shortcut
  shown in the assertion-oriented sketch. Add `Constants` keys and injectable read helpers so a
  missing new key can distinguish a fresh installation from a legacy stored placement.

- [ ] **Step 4: Write failing backward-compatible profile tests**

  Add a v1 JSON fixture that omits all three new optional fields and assert it decodes. Assert
  snapshots populate all three fields, validation rejects unknown non-nil raw values, apply writes
  the three live keys, rollback includes them, and legacy fields deterministically supply
  Compact/Standard/Right.

- [ ] **Step 5: Run profile tests and verify RED**

  Run:

  ```bash
  xcodebuild -workspace NumPad.xcworkspace -scheme NumPad \
    -destination 'platform=iOS Simulator,id=5B976E69-A682-4406-BCFD-BCA93FC96352' \
    test \
    -only-testing:NumPadTests/KeyboardProfileTests \
    -only-testing:NumPadTests/KeyboardProfileApplierTests \
    -only-testing:NumPadTests/KeyboardProfileMigrationTests
  ```

  Expected: failures for missing profile fields and live-setting keys.

- [ ] **Step 6: Implement profile capture, validation, apply, and migration**

  Add optional raw fields to `KeyboardProfile.Configuration` so synthesized `Decodable` accepts
  old JSON. New factories and snapshots always populate them. Validation accepts nil, validates
  non-nil values, and the applier resolves nil through the legacy mapping without mutating the
  source profile. Keep `currentSchemaVersion` compatible unless an existing migration test proves
  a schema bump is required.

- [ ] **Step 7: Run focused tests, self-review, and commit**

  Run the Task 1 suites plus `git diff --check`. Commit only Task 1 files:

  ```bash
  git commit -m "feat: add iPad keyboard layout preferences"
  ```

---

### Task 2: Resolve Five Horizontal Numpad Widths in Production

**Files:**

- Modify: `NumPad/Libraries/Qwerty/QwertyLayoutGeometry.swift`
- Modify: `Keyboard/KeyboardViewController.swift`
- Modify: `NumPad/Libraries/Studio/IPadStudioLayout.swift`
- Modify: `NumPadTests/QwertyLayoutGeometryTests.swift`
- Modify: `NumPadTests/IPadSettingsTests.swift`

**Interfaces:**

- Consumes: `NumpadWidthSize` and `UserPrefs.numpadWidthSize` from Task 1.
- Produces:

  ```swift
  NumpadGeometry.resolve(
      width: NumpadWidthSize,
      bounds: CGRect,
      idiom: UIUserInterfaceIdiom,
      horizontalSizeClass: UIUserInterfaceSizeClass?,
      isFloating: Bool
  ) -> NumpadGeometry.ConstraintLayout
  ```

- [ ] **Step 1: Write failing pure-geometry tests**

  For a 1,000-point-wide, 300-point-high iPad bounds rectangle, assert resolved widths of 600, 700,
  800, 900, and 1,000 points, centered origins, and an unchanged 300-point height. Assert phone,
  compact-size-class, width below 700 points, and floating iPad all return the available full
  bounds. Assert the input height is preserved for every width and fallback.

- [ ] **Step 2: Run geometry tests and verify RED**

  Run:

  ```bash
  xcodebuild -workspace NumPad.xcworkspace -scheme NumPad \
    -destination 'platform=iOS Simulator,id=5B976E69-A682-4406-BCFD-BCA93FC96352' \
    test -only-testing:NumPadTests/QwertyLayoutGeometryTests
  ```

  Expected: failure because production geometry still caps regular iPad numpads at 560 points and
  defaults automatic placement to centered.

- [ ] **Step 3: Implement width-only geometry**

  Replace placement-driven production resolution with width-driven resolution. Compute:

  ```swift
  let resolvedWidth = fallbackToFullWidth ? bounds.width : bounds.width * width.fraction
  let frame = CGRect(
      x: bounds.midX - resolvedWidth / 2,
      y: bounds.minY,
      width: resolvedWidth,
      height: bounds.height
  )
  ```

  Keep a legacy placement adapter only for old tests, profiles, or debug routes that still require
  decoding. Do not reference height presets or modify a height constraint in this type.

- [ ] **Step 4: Write a failing controller integration test**

  Add an assertion through the production constraint application path that a Full preference
  produces zero leading/trailing constants and Compact produces equal 20%-of-width outer margins.
  Capture the active input-view height before and after all five applications and assert equality.

- [ ] **Step 5: Wire `KeyboardViewController` to the new geometry**

  Rename `applyAdaptiveNumpadGeometry()` to `applyCurrentNumpadGeometry()`, read
  `UserPrefs.numpadWidthSize`, and update
  only `stackLeadingConstraint.constant` and `stackTrailingConstraint.constant`. Ensure
  `reloadItems()` receives the resolved content width so `StackView` calculates appropriate
  horizontal key metrics. Leave `applyDefaultHeight()` unchanged.

- [ ] **Step 6: Update the permanent-dock horizontal resolver**

  Replace `IPadStudioLayout.Input.placement` with `numpadWidthSize`. Preserve the existing
  requested-dock-height formula byte-for-byte. For a numpad preview the dock width follows the
  resolved five-step width and remains centered; narrow contexts fall back to full safe width.
  Add tests proving every height preset produces the same dock height before and after changing
  only width.

- [ ] **Step 7: Run focused tests, self-review, and commit**

  Run `QwertyLayoutGeometryTests` and `IPadSettingsTests`, then `git diff --check`. Commit:

  ```bash
  git commit -m "feat: add five iPad numpad widths"
  ```

---

### Task 3: Build Standard and Full iPad QWERTY Compositions

**Files:**

- Modify: `NumPad/Libraries/Qwerty/QwertyLayoutGeometry.swift`
- Modify: `Keyboard/Views/QwertyKeyboardView.swift`
- Modify: `Keyboard/Libraries/QwertyPageHost.swift`
- Modify: `Keyboard/KeyboardViewController.swift`
- Modify: `NumPad/Libraries/Qwerty/QwertyPersonalizationContext.swift`
- Modify: `NumPadTests/QwertyLayoutGeometryTests.swift`
- Modify: `NumPadTests/QwertyKeyboardViewHitTestTests.swift`
- Modify: `NumPadTests/QwertyPersonalizationContextTests.swift`
- Modify: `NumPadTests/QwertyLayerRulesTests.swift`

**Interfaces:**

- Consumes: `IPadQwertyLayout` and `FullKeyboardNumpadSide` from Task 1.
- Produces:

  ```swift
  struct IPadKeyboardCompositionGeometry {
      struct Layout: Equatable {
          let qwertyFrame: CGRect
          let numpadFrame: CGRect?
      }

      static func resolve(
          bounds: CGRect,
          idiom: UIUserInterfaceIdiom,
          horizontalSizeClass: UIUserInterfaceSizeClass?,
          layout: IPadQwertyLayout,
          numpadSide: FullKeyboardNumpadSide
      ) -> Layout
  }
  ```

- Full Keyboard uses a 68% QWERTY pane, an 8-point divider gap, and the remaining width for the
  numpad pane. Both frames retain the full input bounds height.

- [ ] **Step 1: Write failing composition tests**

  Assert Standard returns the entire bounds as `qwertyFrame` and nil `numpadFrame`. Assert Full
  returns non-overlapping, in-bounds frames with the exact 68% QWERTY share and 8-point gap, mirrors
  correctly for Left/Right, and preserves the input height in both panes. Assert phone and compact
  fallback return Standard.

- [ ] **Step 2: Run focused tests and verify RED**

  Run:

  ```bash
  xcodebuild -workspace NumPad.xcworkspace -scheme NumPad \
    -destination 'platform=iOS Simulator,id=5B976E69-A682-4406-BCFD-BCA93FC96352' \
    test \
    -only-testing:NumPadTests/QwertyLayoutGeometryTests \
    -only-testing:NumPadTests/QwertyKeyboardViewHitTestTests
  ```

  Expected: failure because the QWERTY and numpad views are mutually exclusive full-bleed pages.

- [ ] **Step 3: Implement the pure composition**

  Add the resolver beside existing keyboard geometry. Remove new-production dependence on centered,
  split, and compact modes while retaining legacy raw-value decoding. Standard QWERTY frame
  calculation uses all available width. Remove split-gap hit routing only after the replacement
  pane-boundary tests fail and then pass.

- [ ] **Step 4: Keep the iPad number row visible**

  Add a layout-aware `QwertyPageHost` rule: on iPad Standard or Full Keyboard, the top strip is
  always `QwertyTopStrip.numbers`; `activate(fromNumpadPage:)` and settings refresh must not replace
  it with an alternate pack. Preserve the existing swappable top-strip behavior on iPhone. Add a
  focused failing-then-passing `QwertyLayerRulesTests` case.

- [ ] **Step 5: Compose the real interactive views**

  Retain the QWERTY container's leading/trailing constraints in `KeyboardViewController`. When the
  active page is QWERTY:

  - Standard hides the numpad `stackView` and gives QWERTY the full input bounds.
  - Full Keyboard keeps both `qwertyPageHost.containerView` and the existing interactive
    `stackView` visible.
  - Apply the resolver's horizontal frames through leading/trailing constants.
  - Re-run `reloadItems()` for the side pane so the active pack, custom keys, order, theme, grid,
    corners, long-press actions, overlays, and input behavior are reused.
  - Keep `currentPage == .qwerty`, so QWERTY text/suggestion lifecycle remains authoritative.

  Do not create a second `StackView` and do not add any height constraint.

- [ ] **Step 6: Update QWERTY personalization contexts**

  Add stable Standard, Full-left, and Full-right iPad contexts, and map legacy
  centered/split/compact contexts without applying their offsets to a new composition. Preserve
  phone automatic context and privacy behavior.

- [ ] **Step 7: Verify extension integration and height invariants**

  Run all Task 3 unit suites. Build the Keyboard target for the iPad simulator. Expose internal
  read-only pane-frame accessors to `@testable import` and assert both visible panes share identical
  minY/maxY. Assert switching Standard <-> Full-left <-> Full-right leaves the input-view height
  constant.

- [ ] **Step 8: Self-review and commit**

  Run `git diff --check` and commit:

  ```bash
  git commit -m "feat: add full iPad keyboard composition"
  ```

---

### Task 4: Add Simplified iPad Layout Controls and Immediate Refresh

**Files:**

- Modify: `NumPad/Libraries/Studio/StudioSettingsWriter.swift`
- Modify: `NumPad/Controllers/Studio/SizeAndFeelStudioViewController.swift`
- Modify: `NumPad/Controllers/Studio/LettersStudioViewController.swift`
- Modify: `NumPad/Controllers/Studio/KeyboardStudioViewController.swift`
- Modify: `NumPad/Controllers/Studio/IPadStudioWorkspaceViewController.swift`
- Modify: `NumPad/Controllers/ProfileEditorViewController.swift`
- Modify: `NumPadTests/StudioSettingsWriterTests.swift`
- Modify: `NumPadTests/KeyboardStudioRefreshTests.swift`
- Modify: `NumPadTests/KeyboardProfileTests.swift`
- Modify: `NumPadUITests/IPadStudioUITests.swift`

**Interfaces:**

- Consumes all Task 1 preferences.
- Produces `StudioPreviewContext` with `.numpad`, `.qwerty`, and `.lastUsedPage`.
- Produces writer methods:

  ```swift
  func setNumpadWidthSize(_ value: NumpadWidthSize)
  func setIPadQwertyLayout(_ value: IPadQwertyLayout)
  func setFullKeyboardNumpadSide(_ value: FullKeyboardNumpadSide)
  ```

- [ ] **Step 1: Write failing writer and refresh tests**

  For each new writer method, assert one shared-default write, exactly one injected
  `postSettingsSync` call, and exactly one injected app-local refresh call. Assert width writes do
  not touch `Constants.heightPreset`.

- [ ] **Step 2: Run writer tests and verify RED**

  Run:

  ```bash
  xcodebuild -workspace NumPad.xcworkspace -scheme NumPad \
    -destination 'platform=iOS Simulator,id=5B976E69-A682-4406-BCFD-BCA93FC96352' \
    test -only-testing:NumPadTests/StudioSettingsWriterTests
  ```

  Expected: failure because the new writer methods and local refresh channel do not exist.

- [ ] **Step 3: Implement the writer and preview context**

  Add an injectable app-local notification closure after the defaults mutation and before/after
  the single Darwin post consistently. `IPadStudioWorkspaceViewController` observes the local
  notification and refreshes its existing dock instance using its current
  `StudioPreviewContext`. Prevent duplicate observer registration.

- [ ] **Step 4: Add the five visual horizontal-width choices**

  In Size & Feel, add an iPad-only "NUMPAD WIDTH" section above "KEY HEIGHT". Create five
  `StudioTileView` controls with accessibility identifiers:

  ```text
  studio.size-feel.width.compact
  studio.size-feel.width.comfortable
  studio.size-feel.width.medium
  studio.size-feel.width.wide
  studio.size-feel.width.full
  ```

  Each exposes its percentage as the accessibility value. Selection writes immediately, updates
  selection state, and requests `.numpad` preview context. Do not modify height selection code.

- [ ] **Step 5: Add exactly two QWERTY choices**

  In Letters on iPad, add Standard and Full Keyboard tiles. Full reveals a Left/Right segmented
  control; Standard hides it while preserving the stored side. Both request `.qwerty` preview
  context. On iPhone these controls are absent and existing typing toggles remain unchanged.

- [ ] **Step 6: Simplify profile editing**

  Replace the visible legacy centered/split/compact and numpad-placement cycling with the five
  width choices and two QWERTY choices plus side. Preserve legacy profile decoding but never show
  legacy jargon in the normal editor.

- [ ] **Step 7: Add UI tests**

  Assert all five width controls appear only on iPad, Full is selected in a fresh suite, selecting
  Compact does not change the dock height, Letters shows only Standard/Full, and the side control
  is conditional. Use the stable IDs above. Log `numpad_width_changed`,
  `ipad_qwerty_layout_changed`, and `ipad_full_keyboard_numpad_side_changed` with only the approved
  enum raw value; add no dimensions or user content.

- [ ] **Step 8: Run focused unit/UI tests, self-review, and commit**

  Run `StudioSettingsWriterTests`, `KeyboardStudioRefreshTests`, and the new targeted iPad UI
  methods. Run `git diff --check`. Commit:

  ```bash
  git commit -m "feat: add simplified iPad layout controls"
  ```

---

### Task 5: Make the Permanent Bottom Preview Truthful and Unique

**Files:**

- Modify: `NumPad/Libraries/StudioKeyboardPreviewModel.swift`
- Modify: `NumPad/Views/StudioKeyboardPreviewView.swift`
- Modify: `NumPad/Views/StudioKeyboardDockView.swift`
- Modify: `NumPad/Controllers/Studio/IPadStudioWorkspaceViewController.swift`
- Modify: `NumPad/Controllers/Studio/KeyboardStudioViewController.swift`
- Modify: `NumPad/Controllers/Studio/AppearanceStudioViewController.swift`
- Modify: `NumPad/Controllers/Studio/KeySetStudioViewController.swift`
- Modify: `NumPad/Controllers/Studio/SizeAndFeelStudioViewController.swift`
- Modify: `NumPad/Controllers/Studio/LettersStudioViewController.swift`
- Modify: `NumPad/Controllers/ThemeViewController.swift`
- Modify: `NumPad/Views/OnboardingKeyboardMockView.swift`
- Modify: `NumPadTests/StudioKeyboardPreviewTests.swift`
- Modify: `NumPadTests/IPadSettingsTests.swift`
- Modify: `NumPadTests/KeyboardStudioRefreshTests.swift`
- Modify: `NumPadUITests/IPadStudioUITests.swift`

**Interfaces:**

- Consumes the shared numpad and composition geometry from Tasks 2 and 3.
- Extends `StudioKeyboardPreviewModel` with numpad width, iPad QWERTY layout, side, and separately
  addressable QWERTY/numpad caption rows for a composite render.
- Shared editor controllers accept `showsInlinePreview: Bool = true`; the iPad workspace passes
  false while phone call sites retain the default.

- [ ] **Step 1: Write failing preview-model parity tests**

  Assert `.current(idiom: .pad)` snapshots all three new preferences. Assert numpad rows still come
  from production `PackKeys`/`Item` data. Assert Full Keyboard contains QWERTY rows and active
  numpad rows simultaneously. Assert width changes do not change `aspectRatio`, height preset, or
  rendered content height.

- [ ] **Step 2: Run preview tests and verify RED**

  Run:

  ```bash
  xcodebuild -workspace NumPad.xcworkspace -scheme NumPad \
    -destination 'platform=iOS Simulator,id=5B976E69-A682-4406-BCFD-BCA93FC96352' \
    test -only-testing:NumPadTests/StudioKeyboardPreviewTests
  ```

  Expected: failure because the model can render only one uniformly full-width page.

- [ ] **Step 3: Render with the shared horizontal geometry**

  Update `StudioKeyboardPreviewView.render()` to derive the numpad, QWERTY, and composite panes from
  the shared geometry. Reuse the existing key styling and caption creation. Apply width only to
  horizontal frames; retain the existing `heightFraction`, `keyboardHeight`, caption strip, and
  aspect-ratio calculations.

- [ ] **Step 4: Keep exactly one iPad live preview**

  Remove `contextualCanvas` from the iPad rail. Instantiate iPad destination controllers with
  `showsInlinePreview: false`; phone defaults retain one main-screen preview. Hide/remove iPad
  inline previews from Keyboard, Appearance, Choose Keys, Size & Feel, Letters, and Theme without
  removing their controls.

  Keep saved-setup projected thumbnails. Relabel onboarding animation as "Example" and saved setup
  imagery as "Setup preview"; no decorative or projected surface uses "LIVE PREVIEW".

- [ ] **Step 5: Verify dock structure and immediate mutation**

  Assert the dock remains a safe-area-bottom structural sibling, not scroll content. Assert its
  preview object identity does not change when a setting changes. Assert switching width/layout,
  pack, number order, theme, grid, corners, or editor context updates the existing model
  immediately.

- [ ] **Step 6: Add duplicate-label and visual UI coverage**

  Add an iPad UI test that navigates Keyboard, Appearance, Choose Keys, Size & Feel, Letters, and
  Theme and finds exactly one `studio.keyboard-dock` and no `"LIVE PREVIEW"` static text. Capture
  screenshots for Full numpad, Compact numpad, Standard QWERTY, Full-left, and Full-right.

- [ ] **Step 7: Run focused tests, self-review, and commit**

  Run `StudioKeyboardPreviewTests`, `IPadSettingsTests`, `KeyboardStudioRefreshTests`, and the new
  targeted iPad UI test. Run `git diff --check`. Commit:

  ```bash
  git commit -m "feat: make iPad keyboard preview truthful"
  ```

---

### Task 6: Localize, Integrate, and Verify on iPad and iPhone

**Files:**

- Modify: `NumPad/Base.lproj/Localizable.strings`
- Modify: every supported `NumPad/*.lproj/Localizable.strings`
- Modify: `NumPadUITests/IPadStudioUITests.swift`
- Modify: `NumPadUITests/KeyboardStudioUITests.swift`
- Add: `docs/release/2026-07-30-ipad-keyboard-width-preview-evidence.md`
- Modify production/tests only for defects reproduced by a failing regression test.

**Interfaces:**

- Consumes all prior tasks.
- Produces release evidence; performs no Apple submission action.

- [ ] **Step 1: Complete localization and accessibility**

  Add parseable strings for width names, percentages, Standard, Full Keyboard, Numpad side, Left,
  Right, Example, Setup preview, and composite preview summaries. Reuse exact existing
  translations where meanings match; record machine-translated additions as requiring native
  review. Verify Dynamic Type, RTL, selected traits, 44-point targets, and non-color-only
  selection.

- [ ] **Step 2: Parse resources and run static checks**

  Run `plutil -lint` for plists and every `.strings` file, then `git diff --check`. Confirm no
  height-owner files changed outside the horizontal composition call sites.

- [ ] **Step 3: Run the complete unit suite**

  Run from clean DerivedData:

  ```bash
  xcodebuild -workspace NumPad.xcworkspace -scheme NumPad \
    -destination 'platform=iOS Simulator,id=5B976E69-A682-4406-BCFD-BCA93FC96352' \
    -derivedDataPath /private/tmp/NumPad-iPadWidth-Unit-DD test
  ```

  Record exact passed, failed, and skipped counts plus the `.xcresult` path.

- [ ] **Step 4: Run targeted signed iPad UI tests**

  Run the width, Standard/Full-left/Full-right, duplicate-preview, portrait/landscape, and height
  invariance methods in `IPadStudioUITests` on
  `5B976E69-A682-4406-BCFD-BCA93FC96352`. Record screenshots and `.xcresult`.

- [ ] **Step 5: Run iPhone regression coverage**

  Build and run targeted `KeyboardStudioUITests` on
  `37B2DC99-7B78-441D-9F09-220DA1D51CDD`. Confirm width/layout controls are absent, the existing
  QWERTY/numpad page switch still works, and keyboard height is unchanged.

- [ ] **Step 6: Build app and extension for simulator and generic devices**

  Build Debug for the QA iPad and iPhone simulators. Build Release for generic iOS Simulator and
  generic iOS Device destinations. Do not archive.

- [ ] **Step 7: Perform visual/device comparison**

  Install and launch the merged result on the QA 13-inch iPad simulator. Compare the real
  extension with the permanent dock at all five numpad widths and at Standard, Full-left, and
  Full-right QWERTY. Exercise Regular, Tall, and Kiosk height before and after width changes and
  record that vertical size is unchanged. Smoke-test the connected iPhone if available.

- [ ] **Step 8: Record evidence, self-review, and commit**

  Record commands, results, screenshots, known native-translation review items, and explicit
  confirmation that no archive/upload/submission occurred. Commit:

  ```bash
  git commit -m "docs: record iPad keyboard width verification"
  ```
