# Task 4 — Phone Keyboard Studio

## Delivered

- Expanded `KeyboardStudioViewController` to log source/state-only quick-change analytics and route to focused Studio screens.
- Added Appearance, Choose keys, Size & feel, and feature-gated Letters screens with truthful, immediately refreshed previews.
- Added the seven-choice `StudioKeySetCatalog`: Numbers, Calculations (one tile for math/math2), Prices, Measurements, Date & time, Symbols, and Programming.
- Added the injectable `StudioSettingsWriter`. Production uses `UserDefaults.group` and one `SettingsSync.post()` per write; injected defaults/sync closures make its effects directly testable.
- Locked key choices are rejected by the writer before a write or sync, then routed by the UI to `StoreViewController` with a source-specific value. Entitlement refresh rebuilds the key tiles when returning from Pro.
- Kept Letters inaccessible when `FeatureFlags.isQwertyPageAvailable` is false; autocorrect retains its existing false default.

## Files

- `NumPad/Controllers/Studio/KeyboardStudioViewController.swift`
- `NumPad/Controllers/Studio/AppearanceStudioViewController.swift`
- `NumPad/Controllers/Studio/KeySetStudioViewController.swift`
- `NumPad/Controllers/Studio/SizeAndFeelStudioViewController.swift`
- `NumPad/Controllers/Studio/LettersStudioViewController.swift`
- `NumPad/Libraries/Studio/StudioKeySetCatalog.swift`
- `NumPad/Libraries/Studio/StudioSettingsWriter.swift`
- `NumPadTests/StudioKeySetCatalogTests.swift`
- `NumPadTests/StudioSettingsWriterTests.swift`
- `NumPadUITests/KeyboardStudioUITests.swift`
- `NumPad.xcodeproj/project.pbxproj` (generated only by `ruby scripts/add_sources.rb`)

## RED → GREEN evidence

1. RED: the catalog/writer test target failed because `StudioSettingsWriter` did not exist.
2. GREEN: catalog and writer behavior passed after the minimal catalog/writer implementation.
3. RED: the locked-choice writer test failed because selection accepted an ID and returned no result.
4. GREEN: writer now accepts the locked-aware catalog choice and returns false before defaults/sync work.
5. RED: focused UI navigation tests failed against the original Theme/Packs/Height routes.
6. GREEN: the focused Studio routes and accessibility queries pass.

## Validation

- `xcodebuild test -workspace NumPad.xcworkspace -scheme NumPad -destination 'platform=iOS Simulator,id=37B2DC99-7B78-441D-9F09-220DA1D51CDD' -only-testing:NumPadTests/StudioKeySetCatalogTests -only-testing:NumPadTests/StudioSettingsWriterTests -only-testing:NumPadUITests/KeyboardStudioUITests`
  - Passed: 9 unit tests and 4 signed phone UI tests.
- `xcodebuild build -workspace NumPad.xcworkspace -scheme NumPad -destination 'platform=iOS Simulator,id=37B2DC99-7B78-441D-9F09-220DA1D51CDD'`
  - Passed with local simulator signing (`Sign to Run Locally`).
- `git diff --check`
  - Passed.

## Self-review

- No Studio controller writes a keyboard setting directly; all Studio setting mutations flow through `StudioSettingsWriter`.
- Analytics carries only source/state values; no typed content is read or logged.
- The Studio row/tile components enforce 44-point minimum touch targets and expose stable identifiers.
- Key catalog excludes Cooking and duplicate Math, includes Date & time, and preserves the Math toggle behavior.
- The focused UI suite queries elements by their actual accessibility role (`Button`) after an initial role mismatch was found during RED validation.

## Concerns

- The readiness UI test validates the hero's reported ready/needs-attention state. The signed simulator already has NumPad enabled, so it cannot safely force the needs-attention branch without altering system keyboard configuration.
- Xcode emitted pre-existing simulator/runtime warnings about an empty build number, debugger version lookup, duplicate accessibility loader classes, and simulator CoreTelephony; none caused a test or build failure.

## Fix Round 1 — Readiness, effective height selection, and phone UI coverage

### Changes

- `KeyboardStudioViewController` now owns and refreshes its readiness hero in `viewWillAppear`, so returning from setup or iOS Settings updates both the state text and the repair action. A `#if DEBUG` `-debugStudioKeyboardReady 0|1` presentation override gives signed UI tests deterministic ready and needs-attention states without writing settings or entering release builds.
- `SizeAndFeelStudioViewController` derives selection from `KeyboardHeightPreset.effective(stored:kioskEntitled:)`, refreshes its height tiles after writes and reappearance, and retains the Kiosk Pro lock while a persisted unentitled Kiosk value visibly falls back to Tall.
- Added controller coverage for readiness transition, persisted Kiosk fallback/lock state, and immediate height-tile refresh. Strengthened signed phone UI coverage for both hero states, visible free/locked traits, locked-tile Pro routing without selection mutation, and accessibility-size focused controls that are visible, scrollable, hittable, and retain a 44-point touch target.

### RED → GREEN evidence

1. RED:
   `xcodebuild test -workspace NumPad.xcworkspace -scheme NumPad -destination 'platform=iOS Simulator,id=37B2DC99-7B78-441D-9F09-220DA1D51CDD' -only-testing:NumPadTests/KeyboardStudioRefreshTests`
   - Failed to compile before implementation: the new tests required the missing `keyboardReady`, `storedHeight`, `kioskEntitled`, and `heightChoices` test seams.
2. GREEN:
   `xcodebuild test -quiet -workspace NumPad.xcworkspace -scheme NumPad -destination 'platform=iOS Simulator,id=37B2DC99-7B78-441D-9F09-220DA1D51CDD' -only-testing:NumPadTests/KeyboardStudioRefreshTests -only-testing:NumPadTests/StudioSettingsWriterTests -only-testing:NumPadTests/StudioKeySetCatalogTests`
   - Passed: 12 tests, 0 failures.
3. RED:
   Initial strengthened UI run exposed two test-query corrections: unlocked tiles expose an empty accessibility value rather than `nil`, and a large-text tile must be scrolled fully into the viewport before frame assertions.
4. GREEN:
   Each signed focused UI test passed on `37B2DC99-7B78-441D-9F09-220DA1D51CDD`: ready hero, needs-attention hero, quick-change round trip, locked/free key-set behavior, and accessibility-size key-set behavior (5 tests, 0 failures). They were run individually because the local Xcode result-bundle process terminates a combined UI batch at about 30 seconds.

### Fix Round 1 validation

- `xcodebuild build -quiet -workspace NumPad.xcworkspace -scheme NumPad -destination 'platform=iOS Simulator,id=37B2DC99-7B78-441D-9F09-220DA1D51CDD' CODE_SIGNING_ALLOWED=YES`
  - Passed with explicit simulator signing enabled.
- `git diff --check`
  - Passed.

### Fix Round 1 concerns

- The headless controller test directly drives `viewWillAppear(false)` to model the setup-return lifecycle because a non-animated push/pop in an XCTest-owned `UIWindow` does not consistently issue appearance callbacks. The production refresh remains in the real `viewWillAppear` path.
- The simulator emits known Xcode/runtime warnings (empty build number, LLDB debugger-version lookup, and stale Metal toolchain paths); validation still completed successfully.
