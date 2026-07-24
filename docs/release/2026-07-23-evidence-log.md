# Codex remediation evidence log

Date: 2026-07-24

Branch: `codex/remediate-qwerty-ipad-kiosk`

Baseline: `7f77d816`

Implementation under verification: `0c343b48fbd50a9231292fb37123ffd416ffcbcf`

Verdict: **NO-GO for TestFlight, archive, upload, or App Store submission**

This log supersedes the incomplete Grok evidence previously stored in this file. The owner
reported that Grok attempted to delegate work to Opus 4.8. The remediation recorded here used
the owner-approved **GPT-5.6-sol/high only, with no Opus or Claude delegation**.

No archive, signing, upload, TestFlight distribution, App Store Connect mutation, or submission
was performed.

## Verification environment

| Item | Value |
|---|---|
| Workspace | `NumPad.xcworkspace` |
| Derived Data | `/Volumes/DevVault/Xcode/DerivedData/NumPad-CodexRemediation` |
| macOS reported by xcresult | 26.5.2 |
| iPhone simulator | QA-iPhone17, iPhone 17 (`iPhone18,3`), iOS 26.5, `37B2DC99-7B78-441D-9F09-220DA1D51CDD` |
| iPad simulator | QA-iPad-Pro-13, iPad Pro 13-inch (M4) (`iPad16,6`), iOS 26.5, `5B976E69-A682-4406-BCFD-BCA93FC96352` |

The dedicated Derived Data directory was validated, moved to the system Trash, and recreated
before the clean run. This was a recoverable removal scoped only to the path above. The app was
then installed and launched with `-skipOnboarding -resetUITestAppGroup` on both simulators.

Pre- and post-verification SHA-256 manifests matched for all tracked files and for the scoped
`NumPad`, `Keyboard`, `NumPadTests`, `NumPadUITests`, and `docs` trees. The verification run did
not silently rewrite source code, tests, or release documents.

## Automated result summary

| Gate | Result | Evidence |
|---|---|---|
| Full unit suite, clean iPad simulator | **PASS** — 876 total, 873 passed, 3 skipped, 0 failed | `Task8-Clean-Full-Unit-iPad.xcresult` |
| Full UI suite, iPhone simulator | **FAIL** — 33 total, 14 passed, 2 skipped, 17 failed | `Task8-Full-UI-QA-iPhone17.xcresult` |
| Full UI suite, iPad simulator | **FAIL** — 33 total, 16 passed, 0 skipped, 17 failed | `Task8-Full-UI-QA-iPad-Pro-13.xcresult` |
| Generic iOS Release build, `NumPad` scheme | **PASS** — unsigned | `/tmp/numpad-codex-task8/device-build-numpad.log` |
| Generic iOS Release build, `Keyboard` scheme | **PASS** — unsigned | `/tmp/numpad-codex-task8/device-build-keyboard.log` |
| Localization syntax | **PASS** — 16 app plus 16 keyboard tables | `plutil -lint` |
| Plist/privacy-manifest syntax | **PASS** — seven files | `plutil -lint` |
| Autocorrect confidence gate | **FAIL** — default remains OFF | `docs/release/2026-07-23-autocorrect-confidence-gate.md` |

The result bundles are under:

`/Volumes/DevVault/Xcode/DerivedData/NumPad-CodexRemediation/Results/`

The textual test logs are:

- `/tmp/numpad-codex-task8/clean-full-unit-ipad.log`
- `/tmp/numpad-codex-task8/full-ui-phone.log`
- `/tmp/numpad-codex-task8/full-ui-ipad.log`

### Clean unit command

```bash
xcodebuild test -workspace NumPad.xcworkspace -scheme NumPad \
  -destination 'platform=iOS Simulator,id=5B976E69-A682-4406-BCFD-BCA93FC96352' \
  -derivedDataPath /Volumes/DevVault/Xcode/DerivedData/NumPad-CodexRemediation \
  -resultBundlePath /Volumes/DevVault/Xcode/DerivedData/NumPad-CodexRemediation/Results/Task8-Clean-Full-Unit-iPad.xcresult \
  -only-testing:NumPadTests CODE_SIGNING_ALLOWED=NO
```

Result: `** TEST SUCCEEDED **`; 876 executed, 3 skipped, 0 failures.

### Full UI commands

```bash
xcodebuild test -workspace NumPad.xcworkspace -scheme NumPad \
  -destination 'platform=iOS Simulator,id=37B2DC99-7B78-441D-9F09-220DA1D51CDD' \
  -derivedDataPath /Volumes/DevVault/Xcode/DerivedData/NumPad-CodexRemediation \
  -resultBundlePath /Volumes/DevVault/Xcode/DerivedData/NumPad-CodexRemediation/Results/Task8-Full-UI-QA-iPhone17.xcresult \
  -only-testing:NumPadUITests CODE_SIGNING_ALLOWED=NO

xcodebuild test -workspace NumPad.xcworkspace -scheme NumPad \
  -destination 'platform=iOS Simulator,id=5B976E69-A682-4406-BCFD-BCA93FC96352' \
  -derivedDataPath /Volumes/DevVault/Xcode/DerivedData/NumPad-CodexRemediation \
  -resultBundlePath /Volumes/DevVault/Xcode/DerivedData/NumPad-CodexRemediation/Results/Task8-Full-UI-QA-iPad-Pro-13.xcresult \
  -only-testing:NumPadUITests CODE_SIGNING_ALLOWED=NO
```

Both commands ended with exit status 65 and `** TEST FAILED **`.

## UI failure inventory

### Shared failures on iPhone and iPad

1. **QWERTY could not be reached in 12 tests.** All 11
   `QwertyRealisticTypingTests` failed before typing, and
   `QwertyTypeSmokeTests.testQwertyTypingAutocapAutocorrectPageSwitchAndPackSwitch` failed for
   the same reason. The test helper looks for an accessible `Letters`/ABC control. The captured
   current numpad exposes a grid glyph but no discoverable `Letters` control, so the suite cannot
   prove callouts, autocorrect undo, suggestions, punctuation, cursor interaction, burst typing,
   or page/pack transitions.

2. **Keyboard height presets did not produce distinct measured input-view heights.**
   `E2EMatrixTests.test10_keyboardAtHeightKiosk_heightsStrictlyIncrease` measured 358 points for
   every phone preset and 408 points for every iPad preset. The expected strict
   small < regular < tall < kiosk ordering was not observed.

3. **Math and conversion screenshot tests lost their selected pack.**
   `ScreenshotCaptureTests.testSlot03_mathPreview` could not find `*`, and
   `testSlot04_conversion` could not find `=`. The setup selects Math, but the later launch resets
   the UI-test app group and erases that selection. This is an isolation/setup defect until the
   intended persistence contract is made explicit.

### iPhone-only failures

- `E2EMatrixTests.test04_heightPicker_lockedThenEntitled` expected the iPad-only Kiosk preset.
- `ProfileAndKioskTests.test_iPadKioskReadinessUsesHumanReadableStatusAndPolicy` expected an iPad
  sidebar while running on iPhone.

These are platform-scoping defects in the full-suite contract.

### iPad-only failures

- `E2EMatrixTests.test11_adaptiveIPadKeyboardGeometryMatrix` stopped because the `Letters`
  keyboard control was missing.
- `ScreenshotCaptureTests.testIPadAdaptiveKeyboardGeometryEvidence` failed before producing the
  required complete adaptive QWERTY geometry set.

The two focused profile/kiosk tests did pass on iPad, but that does not override the red full
matrix.

## Release build and warning audit

The following unsigned generic-device builds both succeeded:

```bash
xcodebuild build -workspace NumPad.xcworkspace -scheme NumPad \
  -configuration Release -destination 'generic/platform=iOS' \
  -derivedDataPath /Volumes/DevVault/Xcode/DerivedData/NumPad-CodexRemediation \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO

xcodebuild build -workspace NumPad.xcworkspace -scheme Keyboard \
  -configuration Release -destination 'generic/platform=iOS' \
  -derivedDataPath /Volumes/DevVault/Xcode/DerivedData/NumPad-CodexRemediation \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
```

The clean app build emitted 28 warning lines:

- 2 first-party warnings:
  - deprecated/ignored `UIButton.contentEdgeInsets` with `UIButtonConfiguration` in
    `SnippetEditorViewController.swift`;
  - a never-mutated `profileStore` variable in `KeyboardProfileApplier.swift`.
- 2 linker warnings for a missing Metal toolchain Swift search path, one per target.
- 22 dependency warnings: 10 FirebaseCrashlytics, 1 SwiftRater, and 11 TextAttributes.
- 2 tooling warnings: skipped App Intents metadata and a symbol-free `dummy.o`.

The NumPad Run Script phase also reports that it runs every build because dependency analysis is
disabled. These warnings are recorded debt; a successful unsigned build is not evidence that
signing, entitlements, archive validation, or installation on hardware will succeed.

## Localization and privacy audit

- Every app and keyboard `Localizable.strings` table parses for:
  `ar`, `de`, `en`, `es`, `fr`, `he`, `hi`, `it`, `ja`, `ko`, `nl`, `pl`, `pt-PT`, `ru`,
  `zh-Hans`, and `zh-Hant`.
- `Info.plist`, both `GoogleService-Info.plist` files, `Settings.bundle/Root.plist`, and both
  privacy manifests parse.
- `docs/PrivacyPolicy` and `docs/PrivacyPolicy.md` are byte-identical.
- The app manifest declares non-linked, non-tracking product-interaction analytics, crash data,
  and performance data. The keyboard manifest declares no collected data. Both declare
  `NSPrivacyTracking = false`, no tracking domains, and UserDefaults required-reason API
  category `CA92.1`.
- Native-speaker review and App Store privacy-label comparison were not performed.

## Autocorrect confidence

The 4,266-pair release diagnostic remains a fail, and autocorrect remains default-OFF:

| Metric | Measured | Gate | Result |
|---|---:|---:|---|
| Auto-apply precision | 0.8023 | >= 0.9500 | **FAIL** |
| Auto-apply coverage | 0.3687 | >= 0.3500 | PASS |
| Visible three-slot candidate rate | 0.9018 | >= 0.9170 | **FAIL** |
| End-to-end p95 latency | 4.1308 ms | < 16.0000 ms | PASS |

Thresholds were not lowered.

## Visual evidence

Valid evidence:

| State | Evidence | Result |
|---|---|---|
| iPad dashboard, portrait | `VisualEvidence/ipad-dashboard-portrait.png`, 2064x2752, SHA-256 `36d14590c653b397006c7f1b52bb09f3c2c8265dbc0eee2935144cfe474984fb` | Readable split-view dashboard, readiness status, profile, Full Access explanation, fallback, Try It, and provisioning actions visible |
| iPad current numpad | iPad UI xcresult attachment `07-keyboard-small` | Centered numpad is visible at the measured 408-point input-view height |
| QWERTY reachability failure | iPhone/iPad UI xcresult attachments and failure activity | Current numpad is visible; required `Letters` accessibility target is not discoverable |

The following are **not valid release evidence**:

- `ipad-numpad-full-width.png` and `ipad-numpad-centered.png` are byte-identical
  (`a53a3f48...a6dad1c`), so they do not prove mode differentiation.
- Phone QWERTY, iPad centered QWERTY, split/compact QWERTY, and complete adaptive geometry were
  blocked by the QWERTY reachability failure.
- Dashboard landscape capture was blocked: simulator geometry rotation failed, and the Mac was
  locked so GUI rotation could not be used.
- A dedicated Kiosk Provisioning screenshot was not captured. The portrait dashboard readiness
  state and passing iPad profile/kiosk UI tests are partial evidence only.

The Mac was locked during the manual pass, and automatic unlock was unavailable. No visual or
interaction state blocked by that condition is marked as passed.

## Unperformed or blocked release gates

| Gate | Status |
|---|---|
| Full iPhone UI matrix | **FAIL** |
| Full iPad UI matrix | **FAIL** |
| Complete visual matrix | **BLOCKED / INCOMPLETE** |
| VoiceOver on physical iPhone and iPad | **NOT PERFORMED** |
| Guided Access kiosk session on physical iPad | **NOT PERFORMED** |
| Real third-party host apps | **NOT PERFORMED** |
| Real MDM and Files-provider provisioning | **NOT PERFORMED** |
| Signed external profile URL | **NOT PERFORMED** |
| Hardware keyboard interaction | **NOT PERFORMED** |
| Native-speaker localization review | **NOT PERFORMED** |
| App Store privacy-label parity | **NOT PERFORMED** |
| Signed archive and validation | **NOT PERFORMED** |
| TestFlight installation and smoke test | **NOT PERFORMED** |
| App Store upload/submission | **NOT PERFORMED** |

## Required next verification

1. Restore an accessible, working ABC/Letters transition contract or update the implementation
   and tests together to the intended accessible control.
2. Determine whether height presets are failing in production or measured incorrectly; make the
   full matrix observe distinct heights.
3. Fix UI-test reset semantics so a selected Math pack survives within a screenshot scenario.
4. Platform-scope iPad-only assertions.
5. Rerun the clean full unit and both complete UI matrices. Do not advance while either UI
   result is red.
6. Capture the full phone/iPad QWERTY, adaptive geometry, numpad mode, dashboard orientation,
   and kiosk-provisioning visual matrix.
7. Complete physical-device, accessibility, third-party host, MDM/Files, signed URL, privacy,
   localization, archive, and TestFlight gates before any App Store submission decision.
