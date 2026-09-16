# Calibration implementation status

Implementation branch: `codex/keyboard-calibration`, based on `codex/qwerty-typing-reliability` at `e05a0a068e3334068333078ad2ae0b9a20e0a1a5`.

Published as [draft PR #14](https://github.com/MoreVoltage/NumPad/pull/14) with user approval. No app has been published, merged, or uploaded to App Store Connect or TestFlight.

## Implemented

### Three-sentence calibration (current)

The user clarified that calibration should measure normal word typing, not isolated letters. It now contains exactly three sentences, with no extra letter drills:

1. The quick brown fox jumps over the lazy dog.
2. Please bring five dozen mugs.
3. We enjoy quiet walks.

The words and spaces total 91 keypresses; final periods are optional. Sentence-initial capitalization is automatic. The first two sentences contain every A–Z letter and supply 59 letter taps for the bounded shared touch-offset model. Spaces are recorded but keep fixed routing. The final sentence supplies 17 independent letter taps across 14 letters for validation and never trains the profile.

- Users type at their normal pace, with Delete available for corrections and one Continue/Save action per sentence.
- Natural alignment tolerates case and unambiguous nearby letter substitutions. Missing, extra, shifted, or ambiguously aligned input cannot silently become training labels. Incorrect attempts can be edited or retried one sentence at a time.
- Activation requires at least two fewer errors than both default and previous routing on the final sentence, with at most 25% candidate errors. This small check is not a claim of real-world accuracy improvement.
- Fingerprint version 3 isolates prior isolated-letter sessions. Earlier completed results retain their original validation rules when read.
- Saved history, resume, recalibration, restore, reset, and compact asynchronous extension profile reads remain.

### Autocorrect and suggestion fixes

- Autocorrect defaults on when no preference exists. An explicit saved off preference is preserved.
- Passing over an uncorrected typo no longer teaches the personal dictionary to protect it. Existing learned data is preserved.
- The suggestion bar offers bounded two-word repairs for missing/mistyped spaces, including `youcan` and `youncan` → `you can`. These suggestions use local dictionary lookups and are never silently auto-applied just because a split is plausible.
- Unexpected mid-sentence capitalization is not diagnosed from the example alone. No blanket casing change was made that could damage intentional shortcuts or names.

### Private swipe calibration

- Reuses the existing glide recognizer and decoder, with a separate endpoint-bias model and storage.
- Each new swipe run requires a fresh matching three-sentence calibration, then covers every intended letter in at least three different words. Crossing a key does not count as intending it.
- The curriculum contains 77 distinct training words and 48 separate validation words. The adaptive planner selects the needed training words.
- Capture uses real coalesced touches with bounded point counts and timestamp ordering. Profiles are applied only when held-out ranking improves.
- `NumPad-PrivateSwipe` uses `PrivateSwipe` configuration, distinct app/extension identifiers, and a separate App Group. Swipe implementation and UI require both `DEBUG` and `NUMPAD_PRIVATE_SWIPE`.
- Ordinary Debug and Release cannot enable swipe through stale preferences. The private scheme and app/extension build guards reject private archives. Product inspection checks the app, embedded extension, and swipe-specific resources.
- No App Store or TestFlight delivery is authorized or included.

## Verification

The current three-sentence and correction revision is awaiting its macOS rerun. Results below describe the previous isolated-letter revision.

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
