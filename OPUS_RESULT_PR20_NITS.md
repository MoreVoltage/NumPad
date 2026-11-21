# PR #20 nit round — Low 4 (Astra re-review)

Branch `key/opus-pr20-nits`, based on the PR #20 head `83ccc005`. Only the test file changed. Product code, layout, copy, pricing, paywall, StoreKit, monetization, URLs, converter logic and version/build are untouched. No subscription IDs were added.

## Fix

All changes are in `NumPadTests/LockedTapResponseTests.swift`.

### (a) The source audit can no longer pass vacuously

- The loader is now `KeyboardSourceAudit.load(keyboardDir:sharedFiles:)`. It throws `keyboardDirectoryMissing` if the Keyboard folder doesn't exist, isn't a directory, or can't be enumerated. It throws `noKeyboardSources` if enumeration yields zero `.swift` files.
- Shared files (`NumPad/Libraries/LockedTapResponse.swift`) are appended **after** that check, so the pre-seeded entry can't satisfy it.
- Paths are resolved relative to the test file via `#filePath` (repo root = test file's grandparent directory). No fixed machine path is used.
- New test `testAuditEnumeratesTheKeyboardController` checks that the real enumeration includes `KeyboardViewController.swift`.
- New tests `testAuditRejectsEmptyKeyboardDirectory` (empty temp dir) and `testAuditRejectsMissingKeyboardDirectory` (nonexistent path).

### (b) Controller forwarding: real-controller drive not feasible, source-level check added

Driving the real `KeyboardViewController` handlers isn't feasible in NumPadTests:

- `KeyboardViewController.swift` belongs only to the Keyboard extension target (one `PBXBuildFile`, in the extension's Sources phase).
- NumPadTests is hosted by and links against the NumPad **app** (`TEST_HOST`/`BUNDLE_LOADER`). An app extension isn't a linkable module, so `@testable import` can't reach the controller.
- Compiling the controller into the test target would also pull in all of its extension-only dependencies: the overlay views, `StackView`/`Cell`/`Button`, `Keyboard/Libraries/*`, and the SwiftyTimer pod. That is a large project-file change, with possible symbol clashes against the app module's own `Extensions.swift`. It's out of scope for a nit round.

What I added instead:

- `testControllerLockedTapHandlersForwardToSharedEntryPoints` reads the real controller source. For each method it extracts the body by brace matching, strips `//` comments and whitespace, and requires the forwarding call:
  - `tapped(_:)` → `LockedTapResponse.handleKeyTap(isLocked: Monetization.isKeyLocked(pack: effectiveKeyboardType, row: position.0), presenter: self) { return }` (the early return is included)
  - `packPickerView(_:didSelectLocked:)` → `handleLockedOverlaySelection(source: .packPicker, presenter: self)`
  - `conversionViewDidSelectLockedCategory(_:)` → `handleLockedOverlaySelection(source: .conversionLock, presenter: self)`
  - `showLockedTapHint(_:)` → `lockedTapHintCoordinator.present(message)`
  - `dismissOverlaysForLockedTap()` → `dismissOverlays()`
- `testForwardingCheckCatchesARemovedOrCommentedOutCall` is a mutation self-test on the real source. It deletes or comments out each overlay or coordinator forwarding call, and separately removes the `tapped(_:)` early return. Each mutation must produce exactly one violation. Fixture-drift asserts fail loudly if the source text changes shape.

## Red / green

- **Red** (loader refactored but still using the old semantics, new empty/missing-dir tests added): `-only-testing:NumPadTests/LockedTapResponseTests` → 13 tests, **2 failures**. Both `testAuditRejectsEmptyKeyboardDirectory` and `testAuditRejectsMissingKeyboardDirectory` failed with `XCTAssertThrowsError failed: did not throw an error`. That shows the old audit passed on an empty or missing Keyboard directory: the seeded shared file alone made the result non-empty. Log: `/tmp/key-opus/p24-red.log`.
- **Green** (after the fix): full NumPadTests suite → **324 tests, 0 failures, TEST SUCCEEDED** (319 previously plus 5 new). All 16 `LockedTapResponseTests` pass. Log: `/tmp/key-opus/p24-green.log`.
- I recorded no separate red for the forwarding check: it passes on the unchanged controller by design. Its mutation self-test is the evidence that it detects a regression.

## Commands

All runs went through ai-gate on sim-pool-1 (`F04DBD38-737B-450F-BC8B-4AF266E8B5E6`). The simulator was returned after each run, and pool return was confirmed both times.

```
pod install --deployment                      # tracked files unchanged
UDID=$(~/bin/sim-pool checkout --wait --owner $$)
~/bin/ai-gate run --heavy -- xcodebuild test -workspace NumPad.xcworkspace -scheme NumPad \
  -destination "id=$UDID" -parallel-testing-enabled NO -derivedDataPath /tmp/key-opus/p24-dd \
  -only-testing:NumPadTests/LockedTapResponseTests        # red: exit 65, 2 expected failures
~/bin/ai-gate run --heavy -- xcodebuild test ... -only-testing:NumPadTests   # green: exit 0, 324/324
~/bin/sim-pool return $UDID
```

## Commits

- `5514709c` test: keyboard source audit cannot pass vacuously; controller forwarding check
- this report (docs commit on top)

## Open risks

- The forwarding check is **textual**. It catches deleted or commented-out forwarding, a dropped early return and renamed methods. It won't catch runtime problems: the delegate not being assigned, UIKit hit testing, or a call made unreachable by logic added earlier in `tapped(_:)`. An equivalent refactor that changes the call's spelling or formatting, for example splitting the `isLocked:` expression into a local, will make it fail and need updating. That is intended: it fails closed.
- Brace matching is naive (it ignores braces inside string literals). That's fine for the current bodies. An unbalanced brace inside a string literal in one of these methods would confuse it, and the result would be a test failure, not a false pass.
- `#filePath` resolves to the compile-time source location, so the tests must run on the machine that built them. That holds for local and Xcode Cloud `xcodebuild test`, but not for a test bundle copied elsewhere. In that case the audit now **fails** (missing directory) instead of silently passing.
- Still out of scope, as instructed: High 1 (What's New chip, MOR-400) and the Low 5 rendered check.
