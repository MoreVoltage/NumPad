# OPUS_RESULT_VERIFY — PR #18 (live-math chip right after typing)

**Branch:** `key/opus-pr18-verify` (was at `17d95c81`, the tip of `key/opus-chip-trigger-2`) · **Version/build:** unchanged · **Product code:** unchanged

## Verdict: VERIFIED on a simulator, with real screenshots from the real extension

On an iPhone 17 Pro simulator (iOS 26.5, `sim-pool-1`), the UI test makes NumPad the active keyboard and types with NumPad's own keys:
- After it types `1`,`2`,`*` and waits 1.5s (well past the 0.12s debounce), there is **no chip**.
- After it types `8`, the **"= 96" chip appears within 3s**. Nothing else touches the screen between those two steps: no field tap and no caret move.

## Screenshots (`docs/screenshots/pr18/`)
| File | What it shows | How it was made |
|---|---|---|
| `01-before-12x.png` (125 KB) | Field shows `12*` with the cursor after `*`. NumPad keyboard with the Math pack row. No chip. | `XCTAttachment(screenshot: XCUIScreen.main.screenshot())` taken 1.5s after the `*` tap |
| `02-after-12x8-chip.png` (132 KB) | Field shows `12*8`. The **`= 96`** chip is showing at the top-right of the keyboard bar. | Same, taken right after `waitForExistence` on the chip returned true (≤3s after the `8` tap, no other input) |
| `pr18-outcome.txt` | The test's own record: `field value: 12*8`, `chip after '12*': false`, `chip after '8' (no extra tap): true`, `chip label: Insert calculated result, 96` | `XCTAttachment(string:)` |

These are untouched captures (1206×2622, the sim's native resolution), exported with
`xcrun xcresulttool export attachments --path /tmp/key-opus/pr18.xcresult`. They are not mock-ups or harness renders. The extension was driven for real.

## Commits (this branch)
1. `test: PR18 UI test + before/after screenshots for live-math chip`. Adds
   `ScreenshotCaptureTests.testPR18_chipAppearsRightAfterTypingNoExtraTap` (test-only; it reuses the existing
   `selectMathPack`/`tapKeys`/`launchNumPadOnTypingSurface` helpers) and the PNGs. It includes this file.

## Test commands and results
Run from one shell that held the sim (`/tmp/key-opus/pr18-run.sh`). The script returned the sim on exit, and `sim-pool status` afterwards showed it free:
```
UDID=$(~/bin/sim-pool checkout --wait --owner $$)
~/bin/ai-gate run --heavy -- xcodebuild test -workspace NumPad.xcworkspace -scheme NumPad \
  -destination "id=$UDID" -parallel-testing-enabled NO -derivedDataPath /tmp/key-opus/p7-dd \
  -resultBundlePath /tmp/key-opus/pr18.xcresult \
  -only-testing:NumPadTests/MathPreviewRefreshTriggerTests \
  -only-testing:NumPadTests/MathPreviewChipTests \
  -only-testing:NumPadTests/LiveMathPreviewTests \
  -only-testing:NumPadUITests/ScreenshotCaptureTests/testPR18_chipAppearsRightAfterTypingNoExtraTap
~/bin/sim-pool return $UDID
```
→ **TEST SUCCEEDED**
- Chip unit tests: **18 passed, 0 failed**: `MathPreviewRefreshTriggerTests` 5/5, `MathPreviewChipTests` 12/12, `LiveMathPreviewTests` 1/1.
- UI test: **1 passed, 0 failed** (49s).

Setup note: the worktree had no `Pods/`, so I ran `pod install --deployment`, which installs from `Podfile.lock` and changed no tracked files. I also started and then stopped a generic-destination `build-for-testing` prebuild. It was redundant once the test run had the sim, and it produced no artifacts that were used.

## Gaps / observations
- **No pre-fix control run.** I didn't run this UI test against `478430f5` (the pre-fix commit) to show the chip missing there. That would mean swapping product files in this worktree, and `NumPadTests` would no longer compile because the trigger type wouldn't exist. The earlier capture note in `testSlot03_mathPreview` ("chip did NOT appear after tapping keys") is the only pre-fix evidence.
- This covers one simulator and one host (the app's DEBUG typing surface). It isn't a device pass, and it doesn't cover Notes/Messages or iPad. An owner device pass is still needed, as `OPUS_RESULT.md` says.
- Overlay-delegate inserts (snippet, clipboard, tape, and so on) are still not covered, as noted in `OPUS_RESULT.md`.
- **Visual observation (not caused by this PR, not changed):** in both shots, the "What's New" pill covers the `+`/`-` keys of the Math row. In the AFTER shot, the `= 96` chip partly covers the `$`/`(` keys. That's where the chip is designed to sit, but the owner may want to look at it.
