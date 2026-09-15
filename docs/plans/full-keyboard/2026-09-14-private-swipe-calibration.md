# Private swipe calibration implementation

Swipe is James's locally provisioned development experiment. The existing written-FTO
publishing gate in `2026-08-04-glide-legal-gate.md` remains in force; no expiry date enables
publishing. This implementation adds a stricter distribution boundary, not clearance.

## Local build

Use `NumPad.xcworkspace`, scheme `NumPad-PrivateSwipe`, configuration `PrivateSwipe`.
Provision both `com.morevoltage.NumPad.PrivateSwipe` and
`com.morevoltage.NumPad.PrivateSwipe.Keyboard` for James's own devices, including app group
`group.morevoltage.numpad.private-swipe`. The two compilation conditions must be present in
app, extension, and tests: `DEBUG NUMPAD_PRIVATE_SWIPE`. Regular Debug and all Release builds
exclude the implementation. Private defaults and settings notifications have separate names.

The private scheme refuses Archive. Both target build phases run
`scripts/check_private_swipe.py`; run its `--archive` mode on any finished production archive
before export as a second boundary. It rejects private identities, implementation markers,
and swipe resource names in the app and embedded extension. There are no new swipe resources;
the existing word lexicon remains shared with tap autocorrect.

## Exercise and evidence

In Letters, choose the private swipe calibration entry. Complete a fresh full-key tap run for
the exact layout first. Each new swipe run consumes a different completed tap run, covering
all uppercase keys, numbers, symbols, alternates, and controls again. The swipe half uses
adaptive supplied words requiring every alphabet letter in at least three distinct words.
Repeatedly swiping one word or crossing an unprompted key cannot satisfy this ledger.

The shared keyboard renderer supplies actual geometry. Coalesced real touch samples are
ordered and deduplicated by timestamp; predicted samples are never used. Explicit confirmation
of the supplied word and a conservative path-shape plausibility check admit evidence. This
initial trainer learns bounded, shrunk median start/end bias, interpolated along arc length.
It deliberately does not pretend that crossing a letter proves an internal-letter alignment.
The existing decoder still scores complete path shape and location. Tap samples are separate.

Training words and fresh validation words are disjoint. Candidate activation requires strictly
fewer top-1 errors than the current profile, no top-3 regression, and no deterioration against
the default decoder on the same held-out paths. Ties retain the current/default profile.
Completed runs retain compact metrics/profiles; raw paths are removed. Interrupted runs keep
bounded supplied-exercise paths and timing summaries solely to resume the exercise.

## Remaining device gates

These changes have not been compiled with Xcode or tested on an iOS device in this environment.
Run the private Swift tests, normal Debug tests, and a production Release archive. Verify actual
app/extension signing, Full Access off/on reads, touch arbitration, two-thumb tapping,
long-press alternates, cursor movement, rotate/resume, and real held-out accuracy/latency.
The debug controller records control taps without treating them as swipe training; the real
keyboard host retains the existing production tap/hold/cursor behavior for mixed-input tests.
A path-model benefit is not established by synthetic tests or by completing an exercise.
