# OPUS_RESULT_FIX2 — PR #18 second follow-up (live-math chip: stale tap under proxy lag)

Branch `key/opus-pr18-fix2` (local only, not pushed), on top of `26c5c93b`. Review: ASTRA_REVIEW_FIX_PR18.md (not committed).

All runs used `ai-gate run --heavy` on sim-pool simulator `sim-pool-1` (`F04DBD38-…`). The simulator was checked out per run and returned after it. Parallel testing was off and DerivedData was at `/tmp/key-opus/p13-dd`. `pod install --deployment` changed no tracked files.

## Finding (High): a lagging proxy lets a stale tap through — CONFIRMED

### Red (tests written first, run against `26c5c93b` + tests only)
Log: `/tmp/key-opus/p13/red-unit.log`. Result: 14 tests ran, 2 failed with 9 assertion failures. These were the two new tests; the 12 existing trigger and visibility tests passed.

- `MathPreviewRefreshTriggerTests.testTapWhileRefreshPendingWithLaggingProxyLeavesDocumentAndRefreshUntouched`
  - `XCTAssertEqual failed: ("96") is not equal to ("A12*") - a lagging proxy authorized a stale replacement`
  - `XCTAssertEqual failed: ("0") is not equal to ("1") - the tap must not cancel the pending refresh`
  - `XCTAssertNil failed: "Decision(expression: "12*8", insertText: "96", displayText: "96")" - A12* has no result — the refresh hides the chip`
- `MathPreviewRefreshTriggerTests.testTapAfterReportedHostChangeWithLaggingProxyIsInertUntilRefreshShowsLiveResult`
  - `XCTAssertEqual failed: ("A96") is not equal to ("A12*5") - a lagging proxy authorized a stale replacement`
  - `XCTAssertEqual failed: ("0") is not equal to ("1") - the tap must not cancel the pending refresh`
  - `XCTAssertEqual failed: ("Optional("96")") is not equal to ("Optional("60")") - the pending refresh shows the live result`

The first test reproduces the reviewer's exact scenario. The existing `staleProxy` fixture keeps reporting `A12*8` after the real document became `A12*`. The test taps immediately, then lets the proxy catch up and fires the refresh. The second test gets the same lag through a *reported* host change (`hostTextDidChange`) followed by an own key. It then shows that the refresh which eventually fires presents the live result (`60`), and that tapping it applies correctly (`A60`).

### Fix: commit `c0f67aaa` (`NumPad/Libraries/MathPreview.swift` only)
- `MathPreviewRefreshTrigger` has a new private `isActionable` flag. These clear it:
  - every `handleChange`, which means every own edit (`keyboardDidEditText`, which the controller calls after insert/delete/caret moves) and every reported host change (`hostTextDidChange`)
  - `conceal()`
  - `cancel()`
- Only `present(decision)` sets it again, and that happens only from a fresh evaluation.
- `decisionForActivation` now starts with `guard isActionable else { return nil }`. A tap while awaiting re-evaluation is a pure no-op: no document edit, no re-present or hide, and the pending refresh is **not** cancelled. The old `cancelPendingRefresh()` call in activation was removed.
- The earlier safety net still runs when the flag is set: re-derive from the live context, compare with the shown decision, and refuse if text is selected. That covers changes nothing reported, such as a silent host undo.

### Why the chip stays visible but inert (instead of hiding)
- Own edits happen on every keystroke while typing an expression. Hiding on each one would make the chip flicker off and on for every digit.
- The refresh lands within 120 ms anyway and either updates the value or hides the chip. A tap inside that window is simply dropped.
- This needs no UI, layout or animation change.

## Green: final code `c0f67aaa`
Log: `/tmp/key-opus/p13/green.log`. Result bundle: `/tmp/key-opus/p13/green.xcresult`. Outcome: `** TEST SUCCEEDED **`.
- Full NumPadTests: **322 tests, 0 failures** (320 before plus the 2 new ones).
- The 3 previously resolved findings stay resolved. Their existing tests all pass:
  - `testTapDuringDebounceAfterBackspaceNeverDeletesUnrelatedText`
  - `testTapAfterUnreportedDocumentChangeDoesNotApply`
  - `testTapWithSelectedTextDoesNotApply`
  - `MathPreviewChipVisibilityTests.testShowDuringFadeOutSupersedesThePendingHide`
  - the three own-edit lag tests
- PR18 UI tests, run once:
  - `testPR18_chipAppearsRightAfterTypingNoExtraTap`: passed (33.6 s)
  - `testPR18_chipAppearsFromOwnEditsWithHostCallbacksIgnored`: passed (39.9 s)

## Scope
- One production file changed (`MathPreview.swift`, +18/−6), plus two new unit tests.
- No change to layout, the What's New pill or any other UI.
- No version or build bump. No controller change: the tap handler already returns early on nil.

## Open risks
- **Lag longer than the debounce.** If the proxy still reports the pre-edit text when the 120 ms refresh fires, that refresh re-presents the stale decision as actionable. A tap after that could still mismatch. This fix closes the window between an edit and its re-evaluation, as the review asked. It cannot detect a proxy that is still stale after re-evaluation without the keyboard tracking its own expected document, which would be a larger change.
- **Dropped taps.** A tap inside the 120 ms window after any keystroke does nothing and gives no feedback. That is safe, but a fast user may need to tap again.
- **Simulator only.** Proxy lag is reproduced with a unit fixture, not a real lagging host. Not checked on a device.
