# Calibration implementation status

Implementation branch: `codex/keyboard-calibration`, based on `codex/qwerty-typing-reliability` at `e05a0a068e3334068333078ad2ae0b9a20e0a1a5`.

Published as [draft PR #14](https://github.com/MoreVoltage/NumPad/pull/14) with user approval. No app has been published, merged, or uploaded to App Store Connect or TestFlight.

## Implemented

### Quick tap calibration (revised after user feedback)

The original 304-item curriculum was rejected as too burdensome. The user flow now contains **26 key taps in two steps**: 22 distinct letters for learning and four disjoint letters for checking. Every A–Z key is touched exactly once. Including Start and the two confirmations, a clean run takes **29 actions** from the calibration introduction; retries, settings changes, and navigation are additional.

- A highlight advances after each tap. There is no separate confirmation per key, capital/symbol drill, alternate menu, or control exercise.
- This deliberately narrows coverage to the letter keys. The full layout inventory still identifies actual frames and layout compatibility, but symbols, digits, controls, and alternates are not calibration obligations.
- A shared, bounded touch offset is learned from the 22 training taps. One observation per letter does not support an independent per-key model. Uppercase uses the same letter geometry.
- The four check letters never train the model. Activation requires zero candidate errors and at least two fewer errors than both the default and previous routing on that check. This is a conservative short check, not evidence of real-world accuracy improvement.
- Layout fingerprint version 2 isolates older lengthy sessions/profiles. Completed history remains available; its original validation rules are preserved when reading old data.
- Sessions can be resumed or restarted. Every completed run is saved, including declined profiles. Reset and restore remain available.
- The keyboard still reads a bounded active-profile projection asynchronously and uses in-memory offsets during typing.

### Private swipe calibration

- Reuses the existing glide recognizer and decoder, with a separate endpoint-bias model and storage.
- Each new swipe run requires a fresh matching 26-letter tap run, then covers every intended letter in at least three different words. Crossing a key does not count as intending it.
- The curriculum contains 77 distinct training words and 48 separate validation words. The adaptive planner selects the needed training words.
- Capture uses real coalesced touches with bounded point counts and timestamp ordering. Profiles are applied only when held-out ranking improves.
- `NumPad-PrivateSwipe` uses `PrivateSwipe` configuration, distinct app/extension identifiers, and a separate App Group. Swipe implementation and UI require both `DEBUG` and `NUMPAD_PRIVATE_SWIPE`.
- Ordinary Debug and Release cannot enable swipe through stale preferences. The private scheme and app/extension build guards reject private archives. Product inspection checks the app, embedded extension, and swipe-specific resources.
- No App Store or TestFlight delivery is authorized or included.

## Verification

The quick-flow revision passed both simulator test suites, the ordinary Release build, and final swipe-exclusion inspection.

Completed locally:

- Five Python distribution-guard tests, including deliberately misconfigured private archives, flags, bundle IDs, embedded extension symbols, and resources.
- Swipe corpus coverage, uniqueness, and training/validation separation checks.
- Xcode project parse and new-file target membership checks; private scheme and entitlement XML checks.
- Whitespace checks and syntax parsing of the new Swift files.
- Independent review of touch provenance, cross-target profile identity, coordinate normalization, persistence generations, and UI recovery paths; identified issues were fixed.

Completed on macOS with Xcode 26.6 and the iOS 26.5 simulator at `d2f1426bc5032c128524e9fe2ab9d49cafe1d870`:

- Ordinary Debug: 57 selected XCTest cases passed with zero failures.
- PrivateSwipe: 143 selected XCTest cases passed with zero failures.
- Both app and extension targets compiled, and their build-time distribution guards passed.
- Ordinary Release built successfully. Final inspection found no private swipe implementation or swipe-specific resources in the app and embedded extension.
- Quick-flow tests enforce the two-step/26-key/29-action limit, coverage of A–Z exactly once, training/check separation, bounded shared offsets, and legacy validation compatibility.

[Verification workflow and logs](https://github.com/MoreVoltage/NumPad/actions/runs/34928871069).

Remaining device verification:
- Physical-device confirmation of layout parity, Full Access off behavior, gesture feel, latency, and typing benefit. No accuracy or performance improvement is claimed from source inspection alone.
- Testing of genuine globe/dismiss system actions; the calibration practice screen does not invoke them externally.

## Local Mac testing

Open `NumPad.xcworkspace` after `pod install`. Use `NumPad` for ordinary tap calibration. In Letters settings select **Calibrate typing**, match the globe setting to the installed keyboard, and complete the exercises. Recheck in the real extension at the same keyboard size and layout.

For private swipe, use `NumPad-PrivateSwipe` and development signing for `com.morevoltage.NumPad.PrivateSwipe`, its `.Keyboard` extension, and `group.morevoltage.numpad.private-swipe`. Install only on James's development devices. Complete tap calibration within this private installation before entering private swipe calibration. Do not archive or distribute this build.

The dedicated workflow runs calibration/routing/gating tests in both schemes and builds ordinary Release with swipe-exclusion inspection. It does not publish an app.

Existing `numpad://` deep links are shared between the private and production installs; if both are installed, open the desired app directly for settings. Their calibration storage is isolated.
