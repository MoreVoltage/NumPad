# Codex remediation evidence log

Date: 2026-07-26

Branch: `codex/remediate-qwerty-ipad-kiosk`

Baseline: `7f77d816`

Verified implementation HEAD: `6bf3fa815f1643410927ada30293d6244692806b`

Submission verdict: **NO-GO pending physical, external-system, privacy-label, signed-archive, and
TestFlight gates**

Code/simulator verdict: **PASS**

The owner reported that Grok attempted to delegate work to Opus 4.8. This remediation used the
owner-approved **GPT-5.6-sol/high only, with no Opus or Claude delegation**.

No archive, upload, TestFlight distribution, App Store Connect mutation, or App Store submission
was performed.

## Executive result

The final implementation head passes the full unit suite, the complete signed iPhone simulator UI
matrix, the complete signed iPad simulator UI matrix across a full run plus a final-code
replacement for its single time-limited case, both unsigned generic-device Release builds, all
localization/plist/privacy syntax checks, and a visual spot review of the exported green-run
attachments. An independent final code review reported no actionable Critical or Important
findings in the post-review remediation range.

The earlier full UI failures were not product failures. Those commands disabled code signing on
simulator, which removed the shared app-group entitlement and prevented settings, entitlement,
height, pack, and QWERTY state from crossing between the app and keyboard extension. Three
additional test-contract defects were then exposed and corrected:

1. multi-launch screenshot and adaptive-geometry scenarios erased their own setup;
2. iPad-only kiosk/layout assertions ran on iPhone;
3. a realistic typing assertion expected a lower-confidence typo variant to auto-apply despite
   the newer conservative precision policy.

The corrected final matrices use normal simulator signing and preserve the real app-group
contract.

## Verification environment

| Item | Value |
|---|---|
| Workspace | `NumPad.xcworkspace` |
| Derived Data | initial Task-8 runs: `/Volumes/DevVault/Xcode/DerivedData/NumPad-CodexRemediation`; final review runs: `/tmp/numpad-codex-task8/` |
| macOS reported by xcresult | 26.5.2 |
| iPhone simulator | QA-iPhone17, iPhone 17, iOS 26.5, `37B2DC99-7B78-441D-9F09-220DA1D51CDD` |
| iPad simulator | QA-iPad-Pro-13, iPad Pro 13-inch (M4), iOS 26.5, `5B976E69-A682-4406-BCFD-BCA93FC96352` |

The dedicated Derived Data directory had been moved to the system Trash and recreated before the
initial clean Task-8 run. That recoverable removal was scoped only to the path above.

## Final automated result summary

| Gate | Result | Evidence |
|---|---|---|
| Full unit suite | **PASS** — 885 total; 882 passed, 3 skipped, 0 failed | `Review-Remediation-Full-Unit-iPad-v4.xcresult` |
| Full signed iPhone UI suite | **PASS** — 33 total; 28 passed, 5 iPad-only skips, 0 failed | `Review-Remediation-Full-Signed-UI-iPhone17-v4.xcresult` |
| Full signed iPad UI matrix | **PASS, combined** — 32 cases passed in the full run; the sole 120-second timeout passed with a 300-second allowance on final code | `Review-Remediation-Full-Signed-UI-iPad-Pro-13-v4.xcresult`; `Review-Remediation-iPad-Geometry-Replacement-v5.xcresult` |
| Generic iOS Release build, `NumPad` | **PASS** — unsigned compile/link gate | `final-release-numpad-6bf3fa81.log` |
| Generic iOS Release build, `Keyboard` | **PASS** — unsigned compile/link gate | `final-release-keyboard-6bf3fa81.log` |
| Localization syntax | **PASS** — 32 tables | `final-localization-lint-6bf3fa81.log` |
| Plist/privacy-manifest syntax | **PASS** — seven files | `final-plist-privacy-lint-6bf3fa81.log` |
| Privacy-policy source parity | **PASS** | `docs/PrivacyPolicy` and `docs/PrivacyPolicy.md` are byte-identical |
| Autocorrect confidence gate | **FAIL by design** — feature remains default-OFF | `Task8-Final-Autocorrect-Confidence-Gate-v3.xcresult` |
| Independent final code review | **PASS** — no actionable Critical or Important findings | bounded review through `6bf3fa81` |

Final review-remediation result bundles:

`/tmp/numpad-codex-task8/Results/`

Text logs:

`/tmp/numpad-codex-task8/`

### Final unit command

```bash
xcodebuild test -quiet \
  -workspace NumPad.xcworkspace \
  -scheme NumPad \
  -destination 'platform=iOS Simulator,id=5B976E69-A682-4406-BCFD-BCA93FC96352' \
  -derivedDataPath /tmp/numpad-codex-task8/DerivedData-review-full-unit-ipad-v4 \
  -resultBundlePath /tmp/numpad-codex-task8/Results/Review-Remediation-Full-Unit-iPad-v4.xcresult \
  -parallel-testing-enabled NO \
  -only-testing:NumPadTests
```

### Final signed UI commands

These commands intentionally do **not** set `CODE_SIGNING_ALLOWED=NO`.

```bash
xcodebuild test -quiet \
  -workspace NumPad.xcworkspace \
  -scheme NumPad \
  -destination 'platform=iOS Simulator,id=37B2DC99-7B78-441D-9F09-220DA1D51CDD' \
  -derivedDataPath /tmp/numpad-codex-task8/DerivedData-review-full-ui-iphone-v4 \
  -resultBundlePath /tmp/numpad-codex-task8/Results/Review-Remediation-Full-Signed-UI-iPhone17-v4.xcresult \
  -parallel-testing-enabled NO \
  -only-testing:NumPadUITests

xcodebuild test -quiet \
  -workspace NumPad.xcworkspace \
  -scheme NumPad \
  -destination 'platform=iOS Simulator,id=5B976E69-A682-4406-BCFD-BCA93FC96352' \
  -derivedDataPath /tmp/numpad-codex-task8/DerivedData-review-full-ui-ipad-v4 \
  -resultBundlePath /tmp/numpad-codex-task8/Results/Review-Remediation-Full-Signed-UI-iPad-Pro-13-v4.xcresult \
  -parallel-testing-enabled NO \
  -only-testing:NumPadUITests
```

The full iPad command used the test target's explicit 120-second allowance. Its first 32 cases
passed; `test11_adaptiveIPadKeyboardGeometryMatrix` then timed out without an assertion failure.
That same test passed in 263.5 seconds on final implementation commit `6bf3fa81` with a 300-second
allowance, recorded in
`Review-Remediation-iPad-Geometry-Replacement-v5.xcresult`. The combined evidence covers all 33
iPad cases, but no single result bundle should be described as a 33/33 run.

The five iPhone skips are the intended iPad-only cases:

- kiosk height picker entitlement;
- strict kiosk-height growth;
- adaptive iPad keyboard geometry matrix;
- adaptive iPad screenshot evidence;
- iPad kiosk-readiness sidebar.

## UI remediation evidence

### Signed app-group diagnosis

The unsigned simulator install exposed no shared group container for
`group.morevoltage.numpad.container`. With normal simulator signing, both the app and extension
resolved the group and the previously missing state crossed process boundaries:

- the accessible `Letters` transition appeared;
- QWERTY typing and page/pack transitions worked;
- height presets measured distinctly;
- selected Math state survived into the extension;
- entitlement-gated kiosk state was visible.

### Height evidence

The green iPad run measured:

| Preset | Host input-view height |
|---|---:|
| Small | 358 pt |
| Regular | 408 pt |
| Tall | 478 pt |
| Kiosk | 558 pt |

The Kiosk preset is intentionally iPad-only. Production mirrors Tall on iPhone and does not expose
Kiosk selection there, so the strict four-preset ordering test now skips on phone.

### QWERTY behavior evidence

The signed matrices cover:

- autocapitalization and punctuation;
- correct-word verbatim typing;
- checker-head boundary correction;
- lower-confidence variant suggestion without silent replacement;
- literal and candidate suggestion-chip taps;
- backspace and literal-chip correction undo;
- correction-scope invalidation across page changes;
- alternate-key selection on release;
- space tap, quick swipe, and hold-cursor behavior;
- fast typing without phantom capitals;
- QWERTY/numpad page switching and pack cycling.

The `accomodate` case now reflects the production confidence policy. `accommodate` remains visible
as a checker-validated suggestion, but is not auto-applied because it is not the system checker's
first candidate. This is intentional while the release precision gate remains red.

### Scenario-state isolation

`launchNumPad` now accepts an explicit `resetAppGroup` parameter. The default remains true for
test isolation. Only multi-launch scenarios that intentionally write setup in an earlier launch
pass false:

- Math and conversion screenshots preserve their selected pack;
- the adaptive geometry matrix preserves its deterministic custom side column.

## Autocorrect confidence

The valid final gate run set `RUN_AUTOCORRECT_CONFIDENCE_GATE=1` in the simulator launchd
environment, ran the single opt-in test, then removed the environment variable. It failed exactly
as intended:

| Metric | Measured | Gate | Result |
|---|---:|---:|---|
| Auto-apply precision | 0.8023 | >= 0.9500 | **FAIL** |
| Auto-apply coverage | 0.3687 | >= 0.3500 | PASS |
| Visible three-slot candidate rate | 0.9018 | >= 0.9170 | **FAIL** |
| End-to-end p95 latency | 4.1308 ms | < 16.0000 ms | PASS |

Thresholds were not lowered. Autocorrect remains default-OFF. This does not block shipping the
keyboard with suggestions and explicit candidate selection, but it blocks enabling automatic
correction by default.

## Visual evidence

All green-run attachments were exported to:

- `/Volumes/DevVault/Xcode/DerivedData/NumPad-CodexRemediation/VisualEvidence/Task8-Final-Signed-iPhone17-v3/`
- `/Volumes/DevVault/Xcode/DerivedData/NumPad-CodexRemediation/VisualEvidence/Task8-Final-Signed-iPad-Pro-13-v3/`

| Export | Files | Size | `manifest.json` SHA-256 |
|---|---:|---:|---|
| iPhone | 36 | 7.9 MB | `7c17c14bb5bf98142ae520b688ccefeb7d0afa635be54c502612ffe1da41d5b2` |
| iPad | 54 | 22 MB | `190a38cf7bdfe320bf9fdc7a6a60ba2ad74b309307391f8dc24fb89f25768b2d` |

The iPad export includes:

- dashboard and preview;
- locked and entitled Kiosk height states;
- Small, Regular, Tall, and Kiosk keyboard heights;
- automatic, left, right, centered, and full-width numpad layouts;
- centered, split, compact-left, and compact-right QWERTY layouts;
- QWERTY interaction/correction states;
- Store, custom editor, Math, conversion, theme, and height screenshot slots.

Visual spot review found the layouts distinct, readable, unclipped, and consistent with the
geometry assertions. The dashboard uses the larger canvas effectively and exposes kiosk readiness,
keyboard status, active profile, Full Access policy, entitlement fallback, Try It, profiles, and
provisioning.

The green UI tests functionally cover kiosk readiness/provisioning, but this export does not
contain a dedicated provisioning-detail attachment or a landscape-dashboard attachment. Capture
both on the signed physical iPad during the remaining pre-submission visual pass.

One limitation remains: the Math screenshot reliably preserves the Math pack and typed expression,
but the debounced Live Math Preview chip did not appear during automated capture. Pure decision
logic is covered by unit tests, but the chip still requires physical-device timing validation.

## Release build and warning audit

Both generic-device Release builds passed with signing disabled. The current incremental output
contains:

- one missing Metal-toolchain Swift search-path linker warning per target;
- the app Run Script phase note because dependency analysis is disabled.

These are not compile failures. They should be re-evaluated in the exact Xcode/toolchain used for
the signed archive. A successful unsigned build is not evidence that distribution signing,
entitlements, archive validation, or hardware installation will succeed.

## Localization and privacy audit

- Sixteen app and sixteen keyboard `Localizable.strings` tables parse.
- `Info.plist`, both Firebase plists, `Settings.bundle/Root.plist`, and both privacy manifests parse.
- `docs/PrivacyPolicy` and `docs/PrivacyPolicy.md` are byte-identical.
- Native-speaker review and App Store Connect privacy-label parity were not performed.

## Gates still required before Apple submission

| Gate | Status |
|---|---|
| VoiceOver on physical iPhone and iPad | **NOT PERFORMED** |
| Guided Access kiosk session on physical iPad | **NOT PERFORMED** |
| Hardware keyboard interaction | **NOT PERFORMED** |
| Real third-party host apps | **NOT PERFORMED** |
| Landscape dashboard and provisioning-detail physical captures | **NOT PERFORMED** |
| Live Math Preview timing on hardware | **NOT PERFORMED** |
| Real MDM and Files-provider provisioning | **NOT PERFORMED** |
| Signed external profile URL and failure recovery | **NOT PERFORMED** |
| Native-speaker localization review | **NOT PERFORMED** |
| App Store privacy-label parity | **NOT PERFORMED** |
| Signed archive and validation | **NOT PERFORMED** |
| TestFlight installation and smoke matrix | **NOT PERFORMED** |
| App Store upload/submission | **NOT PERFORMED** |

## Required next verification

1. Perform the physical iPhone/iPad keyboard, VoiceOver, hardware-keyboard, third-party-host, and
   Guided Access matrix.
2. Exercise real MDM, Files-provider import/export, signed external profile URLs, and recovery from
   malformed/rejected configuration.
3. Verify Live Math Preview debounce behavior on hardware.
4. Reconcile privacy manifests/policy with App Store Connect labels and complete localization
   review.
5. Produce and validate a signed archive using the intended release Xcode.
6. Install through TestFlight and repeat the smoke/device matrix.
7. Only then make an App Store submission decision.
