# Calibration implementation status

Implementation branch: `codex/keyboard-calibration`, based on `codex/qwerty-typing-reliability` at `e05a0a068e3334068333078ad2ae0b9a20e0a1a5`.

Published as [draft PR #14](https://github.com/MoreVoltage/NumPad/pull/14) with user approval. No app has been published, merged, or uploaded to App Store Connect or TestFlight.

## Implemented

### Tap calibration

- Letters settings opens a full-screen exercise using the production QWERTY renderer and actual key frames.
- The coverage manifest comes from the layout definitions, including the selected top strip, lowercase and uppercase pages, digits, both symbol pages, alternate menus, and controls/hold behaviors.
- Natural phrases are followed by targeted missing-key exercises. Every required item must be completed; a timer cannot finish the run early.
- Raw finger taps retain their physical coordinates. Natural phrases require exact alignment; ambiguous sequences do not train the model. Targeted exercises use explicit intended-key confirmation.
- Letter offsets are bounded and validated using the same routing function as the extension. Held-out input is excluded from training. A candidate must beat both the fixed baseline and the prior calibration before activation.
- Letter geometry is shared across lower/uppercase labels. Digits, symbols, and controls are exercised but retain default recognition in this first implementation. Control exercises are contained practice activations, not verification of real system switching or form submission.
- Sessions can be resumed or restarted. Completed run statistics, including rejected candidates, remain in history; compatible validated profiles can be restored. Reset invalidates stale saves.
- The keyboard reads calibration asynchronously and uses in-memory offsets during typing. A bounded active-profile projection keeps full history and raw unfinished exercises out of extension memory.
- Supervised profiles are protected from the older passive touch-learning heuristic.

### Private swipe calibration

- Reuses the existing glide recognizer and decoder, with a separate endpoint-bias model and storage.
- Each new swipe run requires a fresh matching full-key tap run, then covers every intended letter in at least three different words. Crossing a key does not count as intending it.
- The curriculum contains 77 distinct training words and 48 separate validation words. The adaptive planner selects the needed training words.
- Capture uses real coalesced touches with bounded point counts and timestamp ordering. Profiles are applied only when held-out ranking improves.
- `NumPad-PrivateSwipe` uses `PrivateSwipe` configuration, distinct app/extension identifiers, and a separate App Group. Swipe implementation and UI require both `DEBUG` and `NUMPAD_PRIVATE_SWIPE`.
- Ordinary Debug and Release cannot enable swipe through stale preferences. The private scheme and app/extension build guards reject private archives. Product inspection checks the app, embedded extension, and swipe-specific resources.
- No App Store or TestFlight delivery is authorized or included.

## Verification

Completed locally:

- Five Python distribution-guard tests, including deliberately misconfigured private archives, flags, bundle IDs, embedded extension symbols, and resources.
- Swipe corpus coverage, uniqueness, and training/validation separation checks.
- Xcode project parse and new-file target membership checks; private scheme and entitlement XML checks.
- Whitespace checks and syntax parsing of the new Swift files.
- Independent review of touch provenance, cross-target profile identity, coordinate normalization, persistence generations, and UI recovery paths; identified issues were fixed.

Completed on macOS with Xcode 26.6 and the iOS 26.5 simulator at `17b9509e481aac91615a6690e6a675fc5ab916f9`:

- Ordinary Debug: 55 selected XCTest cases passed with zero failures.
- PrivateSwipe: 141 selected XCTest cases passed with zero failures.
- Both app and extension targets compiled, and their build-time distribution guards passed.
- Ordinary Release built successfully. The final product inspection passed for the app and embedded keyboard extension, with no private swipe implementation or swipe-specific resources detected.
- The initial run exposed throwing-closure inference in six new asynchronous test assertions; the assertions were corrected before this successful test run.

[Verification workflow and logs](https://github.com/MoreVoltage/NumPad/actions/runs/34913077576).

Remaining device verification:
- Physical-device confirmation of layout parity, Full Access off behavior, gesture feel, latency, and typing benefit. No accuracy or performance improvement is claimed from source inspection alone.
- Testing of genuine globe/dismiss system actions; the calibration practice screen does not invoke them externally.

## Local Mac testing

Open `NumPad.xcworkspace` after `pod install`. Use `NumPad` for ordinary tap calibration. In Letters settings select **Calibrate typing**, match the globe setting to the installed keyboard, and complete the exercises. Recheck in the real extension at the same keyboard size and layout.

For private swipe, use `NumPad-PrivateSwipe` and development signing for `com.morevoltage.NumPad.PrivateSwipe`, its `.Keyboard` extension, and `group.morevoltage.numpad.private-swipe`. Install only on James's development devices. Complete tap calibration within this private installation before entering private swipe calibration. Do not archive or distribute this build.

The dedicated workflow runs calibration/routing/gating tests in both schemes and builds ordinary Release with swipe-exclusion inspection. It does not publish an app.

Existing `numpad://` deep links are shared between the private and production installs; if both are installed, open the desired app directly for settings. Their calibration storage is isolated.
