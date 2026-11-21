# OPUS_RESULT_FIX — PR #18 review follow-up (live-math chip trigger)

Branch `key/opus-pr18-fix` (local only, not pushed), on top of `b27b27ee`. Review: ASTRA_REVIEW_PR18.md (not committed).

## Commits
- `d93f52a2` refactor: moves the chip's tap-to-apply decision into `MathPreviewRefreshTrigger` and its fade in/out into a new UIKit-free `MathPreviewChipVisibility`. Behavior is unchanged, so the findings can be reproduced by unit tests that fail on real behavior, not on a missing type.
- `05fa08a7` fix: the fixes for all four findings, the new tests and the DEBUG test hook.

## Red runs
All runs went through `ai-gate --heavy` on a sim-pool simulator (returned after each run), serial, with DerivedData at `/tmp/key-opus/p10-dd`.
- Unit red (`d93f52a2` plus the new tests): `/tmp/key-opus/p10/red-unit-final.log`. 7 of the 12 trigger and visibility tests failed: all 7 new ones, with 10 assertion failures. The 5 existing tests passed.
- My first unit red run (`red-unit-1.log`) had a bug in the test harness. `staleProxy?() ?? document` flattened the optional, so a "nil" context fell back to the document. I fixed the harness and re-ran. The log above is the valid red run.

## Findings

**1. High — stale chip deletes unrelated text: CONFIRMED.**
- Red tests:
  - `testTapDuringDebounceAfterBackspaceNeverDeletesUnrelatedText`: `XCTAssertEqual failed: ("96") is not equal to ("A12*") - a stale chip deleted text it no longer matches`
  - `testTapAfterUnreportedDocumentChangeDoesNotApply`: `("96") is not equal to ("A12*")`
  - `testTapWithSelectedTextDoesNotApply`: `("96") is not equal to ("12*8")`
- Fix: the trigger no longer applies the shown result as-is. On tap, `decisionForActivation` cancels any pending refresh and re-derives the decision from the live `documentContextBeforeInput`. It applies only if the result equals what the chip shows and `selectedText` is empty. Otherwise it refreshes the chip (new value, or hidden) and inserts nothing.
- So every edit, whether or not it was reported, effectively invalidates the shown result. The chip can stay visible for up to 120 ms in the debounce window, but tapping it then can't apply a mismatched result.

**2. Medium — a fade-out swallows a new result: CONFIRMED.**
- Red test: `MathPreviewChipVisibilityTests.testShowDuringFadeOutSupersedesThePendingHide`: `XCTAssertFalse failed - the stale fade-out completion hid the new result` (and alpha `0.0` ≠ `1.0`).
- Fix: `show()` now overrides a fade-out that is still running. A generation token turns the old completion into a no-op, and the controller's fade uses `.beginFromCurrentState`. The same test also checks that a later hide still completes.

**3. Medium — a lagging proxy suppresses the last key's refresh: CONFIRMED.**
- Red tests:
  - `testOwnEditWithStaleTrailingDotContextStillRefreshesOnceContextCatchesUp`: `("nil") is not equal to ("Optional("3.5")")`
  - `testOwnEditWithNilContextStillRefreshesOnceContextCatchesUp`: `("nil") is not equal to ("Optional("26")")`. This test also checks that a stale host callback in the window doesn't cancel the pending read.
  - `testPersistentlyNilContextSchedulesExactlyOneReadAndShowsNothing`: `("0") is not equal to ("1")`
- Fix: context that can't end an expression still hides the chip immediately. Every own edit now also gets one combined delayed re-read. Host callbacks with unusable context hide the chip but don't schedule anything, and they no longer cancel a pending read. A permanently nil context gets one read, shows nothing and doesn't retry.
- I changed one existing test, `testNonExpressionEditHidesImmediatelyAndCancelsPendingRefresh`. It asserted "no pending read after an own edit of a space", which is exactly what this finding replaces. It now asserts: hidden immediately, one pending read, nothing shown after it fires, nothing left pending.

**4. Tests stay green if the controller stops notifying the trigger: CONFIRMED (stated in the review; no code bug).**
- New UI test: `ScreenshotCaptureTests.testPR18_chipAppearsFromOwnEditsWithHostCallbacksIgnored`. It uses a new DEBUG-only hook: the `-debugRoute mathpreview?hostcallbacks=0` route sets `MathPreviewTestHooks.ignoresHostTextCallbacks`, and the keyboard then ignores `textDidChange`/`selectionDidChange` for the chip. That leaves the controller's own-edit call as the only way the chip can appear. The flag is reset on every DEBUG launch and the hook doesn't exist in release builds.
- Red run (`/tmp/key-opus/p10/red-ui.log`): I ran the final code with `defer { mathPreviewTrigger.keyboardDidEditText() }` removed from `tapped`.
  - **Both** PR18 UI tests failed: `XCTAssertTrue failed - chip did not appear after typing '8' without an extra tap`.
  - So on this simulator the host never sends `textDidChange` after the keyboard's own insert. The existing PR18 UI test already catches the missing call here, and the new one catches it no matter what the host sends.
  - I restored the line afterwards. This run also showed the fixes 1–3 unit tests passing.

## Green
Final code, `05fa08a7` (`/tmp/key-opus/p10/green.log`): `** TEST SUCCEEDED **`.
- Full NumPadTests: **320 tests, 0 failures** (313 before plus 7 new).
- Both PR18 UI tests passed: `testPR18_chipAppearsRightAfterTypingNoExtraTap` and `testPR18_chipAppearsFromOwnEditsWithHostCallbacksIgnored`.

## Scope
Only the chip trigger, chip visibility and chip tap logic changed. Nothing else changed: no layout or constraints, no What's New pill, no other UI, no version or build bump. `pod install --deployment` changed no tracked files.

## Open risks
- Tap-time checking trusts `documentContextBeforeInput`. A host that reports old text right after an edit could still let a stale decision pass. This limitation existed before the fix. Truncated context can also still evaluate a suffix that only looks valid.
- During the 120 ms debounce, a visible chip can show the previous value. Tapping it then refreshes the chip and does nothing, so a mismatched result is never applied, but the tap is wasted.
- I couldn't show separately that the host-callback hook takes effect, because on this simulator both UI tests fail with the mutation either way. The hook is a simple flag read through the app group. It should be checked on a host that does send callbacks.
- Own edits now always schedule one timer, including for keys like a space or a decimal point. That's a small cost on the NumPad key path. Typing in other keyboards' prose is not affected.
- Not checked on a device.
