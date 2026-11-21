# PR #20 fix round (store-link compliant variant): result

Branch `key/opus-pr20-fix`, based on the PR #20 head `1245915f` (live base `478430f5`).
These fixes respond to `REVIEW_ASTRA_STORE_LINK_COMPLIANT.md`: Medium 2, Medium 3, Low 4 and Low 5.

## Release gating (the High, out of scope here)

The What's New chip still calls the legacy `openContainerApp` (`numpad://whats-new`). This round
does not touch it. MOR-400 (`key/opus-mor400-remove-chip`) removes the chip. **PR #20 must ship
together with MOR-400, or after it, to close App Review 4.4.1.** Neither branch closes it alone.
Before release, check the integrated tree: no `openContainerApp`/`openURL:` launch is left in
`Keyboard/`, and the helper is deleted.

## Findings

### (A) Medium 2: a repeat tap during fade-out lost its new hint
- **Fix:** a new `LockedTapHintCoordinator` (shared file `NumPad/Libraries/LockedTapResponse.swift`)
  owns the hint's lifetime. Each `present` increments a generation number. The deadline and the
  fade-out completion both capture their token. Only the current generation may start the fade,
  hide the view and restore the chips. A new present cancels the pending deadline. When a stale
  completion arrives during a newer presentation, it is ignored. The controller now only does the
  view work (`LockedTapHintSurface`: show / fade-out / did-hide). The old `lockedTapHintHideWork`
  and the unconditional hide are gone.
- **Tests:** `testTapDuringFadeOutKeepsTheNewHint` and `testTapJustBeforeDeadlineRestartsTheTimer`.
  Both use a virtual-clock `FakeScheduler` and a fake surface that holds fade completions.
- **Red:** with a skeleton that kept the old semantics, `testTapDuringFadeOutKeepsTheNewHint` failed
  4 assertions: the stale completion hid the new hint, the view was hidden, the chips were un-gated,
  and there was 1 hide instead of 0. `testTapJustBeforeDeadline…` failed its gating assertion; the
  cancellation itself already worked, as the review said. **Green:** both pass.

### (B) Medium 3: chip visibility disagreed with tap behavior
- **Fix:** `LockedTapHintCoordinator.allowsChips` (`!isVisible`) is false from `present` until the
  current fade finishes. `KeyboardViewController` checks it in three places:
  - `scheduleMathPreviewRefresh()`, the typing/selection debounce guard. If the hint is up, the math
    chip is hidden and any timer is cancelled.
  - `refreshMathPreviewChip()`, the post-debounce re-check.
  - `refreshWhatsNewChip()`, which covers the settings refresh, `viewWillAppear` and `dismissOverlays`.

  On expiry, `lockedTapHintDidHide()` runs after `isVisible` is cleared. It hides the pill, then
  calls `refreshWhatsNewChip()` and `refreshMathPreviewChip()`, which re-read
  `documentContextBeforeInput`. An unchanged valid expression therefore gets its math chip back. An
  expression edited during the hint is evaluated as it now stands.
- **Tests:** `testHintExpiresAfterDurationAndRestoresChips` checks three things: gated while
  visible, gated during the fade-out, and un-gated *at the moment* the did-hide/restore callback
  runs. `testChipsAllowedWhenNoHintWasShown` is the baseline.
- **Red:** `testHintExpiresAfterDurationAndRestoresChips` failed 2 assertions: the chips were not
  gated while visible or during the fade. **Green:** passes.

### (C) Low 4: tests protected the shared response more than the wiring
- **Fix:** the three controller handlers are now one-line delegations to shared entry points:
  - `tapped(_:)` → `if LockedTapResponse.handleKeyTap(isLocked:presenter:) { return }`. It returns
    `true` only when the key is locked, which gives the early return.
  - `packPickerView(_:didSelectLocked:)` and `conversionViewDidSelectLockedCategory(_:)` →
    `LockedTapResponse.handleLockedOverlaySelection(source:presenter:)`. It calls
    `dismissOverlaysForLockedTap()` **before** showing the hint.
- **Tests:**
  - `testLockedKeyTapShowsHintNoLaunchAndConsumesTap`: consumed, exactly one hint, the counter goes
    up by 1, no store-open, and no legacy or modern open call on a 2-deep spy responder chain.
  - `testUnlockedKeyTapFallsThroughUntouched`.
  - `testLockedOverlaySelectionDismissesOverlayBeforeHintAndNeverLaunches`: the event order is
    `[dismissOverlays, showHint]` for the pack picker and the converter, with no launch.
  - The timing tests from (A) and (B).
  - The source audit, rewritten as `testKeyboardSourcesHaveNoStoreLaunchPath`. It scans **every**
    `.swift` file under `Keyboard/` plus the shared `LockedTapResponse.swift` for `store-preview` and
    `incrementStoreDeeplinkOpens`. It no longer counts `openContainerApp(` occurrences, so it keeps
    working after MOR-400 deletes the helper.
- **Limitation:** `KeyboardViewController` lives in the extension target, and `NumPadTests` is
  hosted by the app. The test bundle cannot instantiate the controller itself. The controller's
  handlers now contain no logic beyond the delegation call. Hit testing and real UIKit animation
  timing still have no automated coverage.
- **Red:** the entry-point tests are extractions of existing behavior, so their red was a compile
  failure against the missing API only. They passed on the skeleton. **Green:** all pass.

### (D) Low 5: hint truncation risk
- **Fix (`Keyboard/Views/LockedTapHintView.swift`, `LockedTapHintLayout`):**
  - `numberOfLines = 2`, with a vertical padding of 5 pt.
  - The fixed 28 pt height is replaced by `height ≥ 28` and `height ≤ cap`. The cap is
    `2 × font.lineHeight + 2 × padding` and is recomputed when the content size category changes.
  - The font scales with Dynamic Type (`UIFontMetrics(.footnote)`, bounded at 19 pt, ×1.25 on iPad).
  - The pill hugs its text, is at most 300 pt wide, stays centered with ≥ 8 pt edge insets, and uses
    `preferredMaxLayoutWidth = 276`.
  - The minimum scale factor is 0.8 and applies only after wrapping.
  - The corner radius is capped at 14, so a two-line pill is a rounded rectangle.
  - `isUserInteractionEnabled = false` is kept, so touches pass through. With (B), no chip sits under
    the pill.
- **Test:** `testHintAllowsTwoLinesWithABoundedHeight` covers the line count, the cap formula, the
  minimum height and that the cap grows with line height. It passed on the skeleton, so it has no
  meaningful red.
- **Screenshot:** not taken. `sim-pool return` wipes user apps, so no pool sim has the NumPad
  keyboard enabled. Enabling it would require Settings.app, which is forbidden here.

## Commits
- `636b78c6` fix: locked-tap hint presentation identity, chip gating, 2-line layout
- (this file) docs: PR #20 fix-round result report

## Test commands
All runs were wrapped in `~/bin/ai-gate run --heavy`, used a sim checked out from the pool, passed
`-parallel-testing-enabled NO` and used `-derivedDataPath /tmp/key-opus/p22-dd`.
`pod install --deployment` left tracked files unchanged.

1. **Red:** `xcodebuild test -workspace NumPad.xcworkspace -scheme NumPad -destination id=<sim-pool-1> -only-testing:NumPadTests/LockedTapResponseTests`
   - **FAIL as intended.** 11 tests ran, 3 failed (7 assertions), all in the gating and fade-out
     identity tests above. Exit code 65.
   - After the tests finished, xcodebuild kept running; I killed it and returned the sim.
2. **Green:** the same command with `-only-testing:NumPadTests` (full unit suite, run once, sim-pool-2).
   - **TEST SUCCEEDED: 319 tests, 0 failures.** The sim was returned.

No UI tests were run.

## Open risks
- **4.4.1 is not closed by this branch alone.** See the release gating section above.
- **Animations:** device behavior is unverified.
  - Interrupting the 0.2 s fade with the 0.15 s fade-in relies on UIKit's additive animations. The
    coordinator logic is covered; on-screen alpha is not.
  - The Reduce Motion paths are synchronous. They are covered by construction, not by a test.
- **Two-line layout:** wrapping, the height cap and Dynamic Type sizes have not been seen on a
  device or simulator. No screenshot exists.
- **Overlap:** a two-line pill (~44–52 pt) covers more of the top key row than the single-line one
  did. Touches still pass through to the keys.
- **Localization:** the hint string still exists only in the English keyboard table. Other locales
  fall back to English, which is unchanged from PR #20.
- **Overlays opened during the hint:** they are still drawn above it, as in PR #20. The chips stay
  gated until the hint expires.
- **No change to:** pricing, paywall, StoreKit, monetization, URLs, the converter logic, the
  version or the build. No subscription IDs were added.
