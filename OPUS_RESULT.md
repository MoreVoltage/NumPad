# OPUS_RESULT — live-math chip "needs an extra tap" (2.1.1)

**Branch:** `key/opus-chip-trigger-2` (off live `478430f5`) · **Version/build:** unchanged (2.1.1 / 15)

## Verdict: REAL BUG (latent in shipping code; the simulator just exposes it reliably)

The chip's only triggers were the system `UITextInputDelegate` callbacks, and iOS does not
guarantee those fire after the keyboard extension's **own** `textDocumentProxy` edits.

### Evidence (live SHA `478430f5`)
- `Keyboard/KeyboardViewController.swift:312-322`: `textDidChange` / `selectionDidChange` were the
  ONLY per-keystroke callers of `scheduleMathPreviewRefresh()`. The other caller is SettingsSync
  (`:151`).
- The doc comment at `:309-311` *assumed* "the system calls this … as a direct result of our own
  `insertText`/`deleteBackward`". Nothing in the code enforces that. Apple documents these
  callbacks as notifications about the document/host, not as an ack of the extension's own proxy
  calls, so whether they fire varies by host and OS.
- `tapped(_:)` (`:597-662`): every key path ends in `textDocumentProxy.insertText(...)` and
  **never** calls `scheduleMathPreviewRefresh()`. The same is true of continuous delete
  (`longPressed`) and the space-bar caret pan.
- Mechanism for "12*8": "12*" has one operand, so `decide` returns nil and no chip shows. The
  final "8" insert triggers no callback, so no refresh is scheduled. The next tap in the field
  fires `selectionDidChange`, which reads the now-complete "12*8", and the chip appears. That is
  exactly the "appears only after an extra tap" symptom.
- An earlier capture note in `NumPadUITests/ScreenshotCaptureTests.swift:91-93` already recorded
  "chip did NOT appear after tapping keys" and called it a "capture-only timing gap". The 0.12s
  debounce can't be the cause: the UI test waits 5s. A missing trigger is.
- Why "real" and not "artifact": on devices/hosts where `textDidChange` does fire after our own
  insert, the chip works. Anywhere it doesn't (the simulator here, and any host that coalesces or
  defers it), the user sees the same bug. The code relied on behaviour iOS doesn't guarantee.

## Fix (commit `872a5f6b`)
- `NumPad/Libraries/MathPreview.swift` (shared, already in both targets, no pbxproj change): adds a
  UIKit-free `MathPreviewRefreshTrigger`. It holds the same cheap guard, 0.12s debounce, and
  fire-time evaluation the VC had inline, with the proxy reads and the scheduler injected.
  Entry points: `keyboardDidEditText()` (our own edits) and `hostTextDidChange()` (system callbacks).
- `Keyboard/KeyboardViewController.swift`: the inline timer logic now delegates to the trigger.
  `keyboardDidEditText()` is called after our own edits: `tapped` (via `defer`, after the overlay
  swallow guard), continuous-delete `longPressed`, and the space-bar caret pan.
  `textDidChange`/`selectionDidChange`/SettingsSync are unchanged in behaviour.
  `hideMathPreviewChip()` still cancels any pending debounce.
- No chip position/UI/feature change. The trigger is not touched in `deinit`, so it is never
  lazily created on a deallocating object; a stale debounce holds the trigger weakly and does nothing.

## Tests
- New: `NumPadTests/NumPadTests.swift` → `MathPreviewRefreshTriggerTests` (5 tests). These deliver
  **zero** host callbacks. Key test: `testChipAppearsAfterTypingExpressionWithNoExtraTapOrHostCallback`
  types 1,2,*,8 the way `tapped` does (insert, then `keyboardDidEditText`), fires the debounce once,
  and asserts the chip shows "96". Also covered: an incomplete expression shows no chip, context is
  read at fire time, a trailing space hides and cancels, and an ineligible state (overlay,
  floating, or toggle off) never schedules.
- Command:
  `~/bin/ai-gate run --heavy -- xcodebuild test -workspace NumPad.xcworkspace -scheme NumPad -destination "id=$UDID" -parallel-testing-enabled NO -derivedDataPath /tmp/key-opus/p4b-dd -only-testing:NumPadTests`
  → **TEST SUCCEEDED, 313 tests, 0 failures** (includes the 5 new ones). The Keyboard target compiled in
  the same build (`KeyboardViewController.o` was built after the final edit).
- RED step: the new tests didn't compile before `MathPreviewRefreshTrigger` existed. There was no
  separate failing run, to save time on the overloaded Mac.
- E2E: see "E2E" below.

## E2E
**NOT RUN.** I queued `-only-testing:NumPadUITests/ScreenshotCaptureTests/testSlot03_mathPreview`
(it taps real keys for `84.50*1.18` and waits up to 5s for the chip). It waited about 45 minutes in
`sim-pool checkout --wait`, because 2 sims were booted machine-wide (another session held
sim-pool-1), and I stopped it. It never held a sim, so nothing needed returning. To run it later:
`UDID=$(~/bin/sim-pool checkout --wait --owner $$); ~/bin/ai-gate run --heavy -- xcodebuild test -workspace NumPad.xcworkspace -scheme NumPad -destination "id=$UDID" -parallel-testing-enabled NO -derivedDataPath /tmp/key-opus/p4b-dd -resultBundlePath /tmp/key-opus/ui1.xcresult -only-testing:NumPadUITests/ScreenshotCaptureTests/testSlot03_mathPreview; ~/bin/sim-pool return $UDID`.
Then read the `03-math-preview-outcome` attachment. It should say "Live Math Preview chip appeared".

## Open risks
- The unit test proves the trigger contract. That `tapped` calls it is verified by code and build,
  not by a unit test, because `KeyboardViewController` isn't in the test target.
- Overlay-delegate inserts (clipboard/snippet/tape/tax-tip/conversion results, `:1047-1199`) still
  rely on host callbacks only. If a pasted snippet ends in an expression, the chip may still wait
  for a tap. Left out of scope to keep the fix minimal.
- If a host updates `documentContextBeforeInput` later than 0.12s after `insertText`, the fire-time
  read could still see stale text. Any later host callback still corrects it, as before.
- Needs an owner device pass (Notes/Messages, iPhone and iPad) before shipping.
