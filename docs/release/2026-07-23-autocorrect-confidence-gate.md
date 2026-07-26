# QWERTY Autocorrect Confidence Gate

Date: 2026-07-23
Corpus: `typos_wiki_en` (4,266 pairs)
Outcome: **FAIL — autocorrect remains default-OFF**

## Current measured result

| Metric | Measured | Frozen gate | Result |
|---|---:|---:|---|
| Auto-apply precision | 0.8023 | ≥ 0.9500 | **FAIL** |
| Auto-apply coverage | 0.3687 | ≥ 0.3500 | PASS |
| Visible three-slot candidate rate | 0.9018 | ≥ 0.9170 | **FAIL** |
| End-to-end p95 latency | 4.1308 ms | < 16.0000 ms | PASS |
| Auto-apply count | 1,573 | — | — |
| Correct auto-applies | 1,262 | — | — |

The latency number is a simulator snapshot, not a promise for all hardware. It includes the
complete production evaluator call for every measured typo: `UITextChecker` misspelling,
guesses and completions; frequency ranking; checker-validated typo-variant probes; suggestion
slot construction; confidence features and decision; and final apply policy. No expensive
step is replaced with a fixture in the opt-in release gate.

“Visible three-slot candidate rate” intentionally measures candidates that the user can
actually tap in the stable three-slot bar. The literal typed word occupies one slot, leaving
up to two candidate chips. Looking at an invisible third ranked guess would overstate the
shipped product.

## Reproduction and test posture

`QwertyConfidenceGateSweepTests.test_metricsCharacterizationUsesFullEvaluatorAndInjectedClock`
runs in the normal unit suite with deterministic fixture spell results and an injected clock.
It characterizes the structured metrics plumbing; it does **not** claim the release gate
passed.

The real release diagnostic is opt-in:

```bash
xcrun simctl spawn <simulator-udid> launchctl setenv RUN_AUTOCORRECT_CONFIDENCE_GATE 1
xcodebuild test -workspace NumPad.xcworkspace -scheme NumPad \
  -destination 'platform=iOS Simulator,id=<simulator-udid>' \
  -only-testing:NumPadTests/QwertyConfidenceGateSweepTests/test_releaseConfidenceGate
xcrun simctl spawn <simulator-udid> launchctl unsetenv RUN_AUTOCORRECT_CONFIDENCE_GATE
```

It asserts every frozen threshold and currently fails on precision and visible top-three
quality. Without the environment variable, XCTest explicitly skips this expensive diagnostic.
The test prints metrics to the test log and never writes this document or any other source
file.

Autocorrect remains `false` by default in `UserPrefs`. Thresholds were not lowered.
