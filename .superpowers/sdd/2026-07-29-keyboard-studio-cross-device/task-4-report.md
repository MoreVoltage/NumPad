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
