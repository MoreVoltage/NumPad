# OPUS_RESULT — MOR-400 nits (Astra review follow-up)

**Branch:** `key/opus-mor400-nits` (local only, not pushed) · **Base:** `c5a9dbdc` · version/build **not** bumped.
Addresses findings 1–3 of `REVIEW_ASTRA_MOR400.md`.

## Changes

### Finding 1: the UI test could modify a pool simulator's Settings
- New **read-only preflight** `skipUnlessNumPadKeyboardAlreadyEnabled()` (`NumPadUITests/UITestSupport.swift`). It launches only the NumPad app on the DEBUG typing surface and reads the text field's accessibility identifier, which reports `Keyboard.isKeyboardEnabled` (the app's existing `AppleKeyboards` read). It throws `XCTSkip` with a clear message when NumPad is not enabled. It **never launches Settings.app**.
- `launchNumPadOnTypingSurface` is split. The keyboard-raising half is now `raiseNumPadOnTypingSurface(extraDebugRoutes:)`, which does not call `ensureKeyboardEnabled()`. The original helper calls `ensureKeyboardEnabled()` and then delegates to it, so the **other tests behave exactly as before**.
- `testMOR400_mathRowPlusMinusUnobstructed` now calls the preflight first and then uses `raiseNumPadOnTypingSurface`.
- DEBUG-only hook: `DebugTypingViewController.fieldIdentifier(keyboardEnabled:)` → `debugTyping.field.numpadEnabled=1|0` is set as the field's accessibility identifier. It is invisible, so the marketing screenshots are unchanged. Existing tests address the field with `textFields.firstMatch`, so they are unaffected.

### Finding 3: deterministic red case
- New DEBUG-only route `-debugRoute whatsnew?seen=0|1` (`DebugDeepLinkRoute.whatsNewSeen(Bool)`). In `ViewController.handleDebugDeepLink`, `0` calls the new `#if DEBUG` `WhatsNew.debugClearSeen()` (clears the stored seen-version and posts `SettingsSync`), and `1` calls `markSeen()`. The route **only writes state**. It never presents the sheet.
- The test seeds `whatsnew?seen=0` on both the setup launch and the typing launch, before the `typing` route raises the keyboard. The removed chip was visible exactly when the recap was unseen (`isChipVisible` == `shouldPresent(lastSeen: nil, 2.1.1)` == true), so restoring it would make the test fail on any prior state.
- Automatic recap presentation is already suppressed by `-skipOnboarding` (the `launchNumPad` default). All three automatic `scheduleWhatsNewIfNeeded()` paths are gated on it or unreachable under it (`finishLaunch`, the `didBecomeActive` observer, and onboarding completion). No new hook was needed for that. The test now also asserts that the sheet heading `What's New in 2.0.3` never appeared, so a "What's New" match can only come from the keyboard.
- Not re-proven red here: restoring the chip was not run, to stay within the one-UI-run budget. The red case rests on the code trace above plus the original red run.

### Finding 2: overstated Full Access explanation
- `OPUS_RESULT_MOR400.md`: H2 is now marked as an **unproven hypothesis**. The row states that Full Access off does not block app-group reads. It also states that the observation does not show the sheet presented or that `markSeen` ran. Both launches used `-skipOnboarding`, so `markSeen` most likely never ran. Open-risk item 3 is corrected. Item 4 now says that the old test *could* open Settings and points here.

### Not touched
Product code paths other than the DEBUG-only hooks above, the live-math chip, the converter, `openContainerApp`, and version/build.

## Tests
- Unit tests added (in `NumPadTests/DebugDeepLinkRouteTests.swift`): parsing `whatsnew?seen=0`/`=1`, rejecting a missing or invalid value, `parseAll` ordering with seed and typing, `debugClearSeen` restoring the unseen state (the group default is saved and restored), and the field-identifier encoding. These were written together with the implementation and run once, not red-first, because of the Mac build budget.

| Run | Command | Result |
|---|---|---|
| Full unit suite | `~/bin/ai-gate run --heavy -- xcodebuild test -workspace NumPad.xcworkspace -scheme NumPad -destination id=<sim-pool-1> -parallel-testing-enabled NO -derivedDataPath /tmp/key-opus/p17-dd -only-testing:NumPadTests` | **PASS**: 317 tests, 0 failures (311 + 6 new). `/tmp/key-opus/p17-unit-1795254873.xcresult` |
| MOR-400 UI test | same, with `-only-testing:NumPadUITests/ScreenshotCaptureTests/testMOR400_mathRowPlusMinusUnobstructed` | **PASS** (26.4s). The preflight found NumPad enabled on sim-pool-1. The log shows 3 NumPad launches and **0 `com.apple.Preferences` launches**. `/tmp/key-opus/p17-ui-1795254929.xcresult` |

- Simulator: sim-pool-1 (iPhone 17 Pro, iOS 26.5), checked out through `sim-pool` and returned after each run. No simulator was created, erased, booted or reconfigured.
- `pod install --deployment` was run. No tracked files changed.

## Open risks
1. The skip branch was not exercised, because sim-pool-1 has NumPad enabled. Its message and logic were reviewed but not run.
2. The preflight trusts `Keyboard.isKeyboardEnabled` (`AppleKeyboards` from the app's standard defaults). A false negative would skip the test, not modify the simulator. It read correctly on sim-pool-1.
3. Other keyboard tests (`E2EMatrixTests`, slot 03/04 screenshots) still use `ensureKeyboardEnabled()` and can still open Settings by design. They were left unchanged, as scoped. Running them on shared pool sims remains a policy question.
4. iPad is still unverified (no iPad in the pool), as in the original report.
5. The review's optional cleanups (unused `WhatsNew.swift` in the Keyboard sources phase, `markSeen` broadcasting `SettingsSync`) are not addressed here. The new `debugClearSeen` follows the same `SettingsSync` pattern.

## Commits (local, unpushed)
- `test(MOR-400): read-only keyboard preflight + seeded unseen recap for UI regression`
- `docs(MOR-400): mark H2 unproven; nits result report`
