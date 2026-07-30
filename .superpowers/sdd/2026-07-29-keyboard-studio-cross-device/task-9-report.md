# Task 9 report — full verification, remediation, and release handoff

## Scope

- Starting accepted Task 8 commit: `175c4966`.
- Ending verification range: `0f584a2c..HEAD` on `codex/keyboard-studio-ux`.
- Worktree: `/Users/jamespikover/NumPad-studio`; workspace: `NumPad.xcworkspace`.
- No external model was used. No push, pull request, archive, upload, TestFlight action, or Apple
  submission action occurred.

## Starting state and range review

The task began with a clean working tree. `git diff --check` was clean at start and after the final
code remediation. The complete range was reviewed for regression-prone areas: profile/Kiosk
authorization, QWERTY fallback, analytics payloads, localization, iPad dock layout, and Glide
scope. The final static scan found no Glide code, promise, or marketing copy added in the reviewed
range.

## Defects reproduced and fixed

| Defect | RED evidence | Minimal remediation | GREEN evidence |
| --- | --- | --- | --- |
| Managed-profile tests persisted a Kiosk fixture without Pro despite the approved guard. | Full units initially failed `test_entitlementFallbackUsesApplierAndRecordsSuccessfulDigest` and `test_sameJSONReappliesWhenFallbackRelevantEntitlementsChange`. | Use an entitled Kiosk fixture and assert the Kiosk path; production guard unchanged (`ba65327c`). | Focused tests and the later full suite passed. |
| iPad first-install UI test mistook the legitimate value/upsell sheet for a missing dock. | Full signed iPad run failed `test_iPadFirstInstallProgressesThroughWowEnableHeightThenTryIt`. | Dismiss/return from the value sheet before asserting the permanent dock (`3f86c110`). | Focused onboarding test 1/1 and full iPad suite 6/6 passed. |
| Four direct Studio dock/preview accessibility keys were absent from every localization catalog. | New focused catalog test failed across all 16 locales. | Added the four English fallback entries and retained catalog coverage (`5316439b`). | Current self-discovering localization gate and final full suite pass. |
| Import-coordinator semantic-Kiosk test used an unentitled default after the July 30 Pro-only import guard. | Exact focused test failed `saveFailed`; log showed `Kiosk mode requires Pro`. | Prepare then store the imported Kiosk with `proEntitled: true`; leave unentitled-rejection coverage in place (`37cdc554`). | Current final full suite passes. |
| Managed coordinator lacked complete negative Pro-only built-in Kiosk state-preservation coverage. | With the production guard temporarily removed, the expanded focused test failed 0/1 with eight assertions. | Retain the production guard; check active profile, complete profile store, live/transaction/Kiosk state, all managed metadata, and SettingsSync count while expecting one diagnostic `stateDidChange`. | Combined current focused gate: 21/21. |
| First-install iPad flow accepted any store navigation bar as the expected interruption. | Source-specific assertion failed 0/1. | Expose `store.first-run-upsell` only for `source == "first_run"`; require it before Back and require return to Studio/dock. | Signed focused iPad test passed 1/1. |
| Localization inventory could silently ignore a newly added relevant source. | A temporary extra discovered Studio Swift file failed the gate 0/1. | Discover the documented include roots, compare with the explicit 37-source set, then apply the 131-key / 16-catalog parse, duplicate, and placeholder gates. | Combined current focused gate: 21/21. |

No production entitlement behavior was weakened. The explicit unentitled import test continues to
assert that Kiosk data cannot be saved.

## Commands and results

### Unit and safety coverage

```sh
xcodebuild test -workspace NumPad.xcworkspace -scheme NumPad -configuration Debug \
  -destination 'platform=iOS Simulator,id=37B2DC99-7B78-441D-9F09-220DA1D51CDD' \
  -only-testing:NumPadTests \
  -resultBundlePath /Volumes/DevVault/Xcode/DerivedData/NumPad-Task9/Task9-FullUnits-Review2-9736f4cb.xcresult \
  CODE_SIGNING_ALLOWED=YES -quiet
```

Final full units at exact tested code commit `9736f4cb`: 972 total, 969 passed, 3 skipped,
0 failed.

Focused safety result bundle `Task9-Safety-Gates.xcresult`: 39 passed, 0 failed, 0 skipped.

The exact focused safety command was:

```sh
xcodebuild test -workspace NumPad.xcworkspace -scheme NumPad -configuration Debug \
  -destination 'platform=iOS Simulator,id=37B2DC99-7B78-441D-9F09-220DA1D51CDD' \
  -only-testing:NumPadTests/KeyboardProfileApplierTests \
  -only-testing:NumPadTests/OnboardingFlowTests \
  -only-testing:NumPadTests/OnboardingHeightSelectionTests \
  -only-testing:NumPadTests/KioskReadinessTests \
  -only-testing:NumPadTests/StudioSavedSetupPresentationTests \
  -only-testing:NumPadTests/StudioSettingsWriterTests \
  -resultBundlePath /Volumes/DevVault/Xcode/DerivedData/NumPad-Task9/Task9-Safety-Gates.xcresult \
  CODE_SIGNING_ALLOWED=YES -quiet
```

The current second-review combined command passed 21/21:

```sh
xcodebuild test -workspace NumPad.xcworkspace -scheme NumPad -configuration Debug \
  -destination 'platform=iOS Simulator,id=37B2DC99-7B78-441D-9F09-220DA1D51CDD' \
  -only-testing:NumPadTests/ManagedProfileCoordinatorTests \
  -only-testing:NumPadTests/IPadSettingsTests/test_studioAndOnboardingDirectLocalizationInventoryIsCompleteAndValid \
  -resultBundlePath /Volumes/DevVault/Xcode/DerivedData/NumPad-Task9/Task9-Review2-Focused-GREEN.xcresult \
  CODE_SIGNING_ALLOWED=YES -quiet
```

The three current RED artifacts are diagnostics, not release results. They were produced with the
following exact commands against the temporary broken condition in each comment:

```sh
# Guard removed temporarily: 0/1, eight failed state-preservation assertions.
xcodebuild test -workspace NumPad.xcworkspace -scheme NumPad -configuration Debug \
  -destination 'platform=iOS Simulator,id=37B2DC99-7B78-441D-9F09-220DA1D51CDD' \
  -only-testing:NumPadTests/ManagedProfileCoordinatorTests/test_unentitledBuiltInKioskRejectionPreservesLastGoodManagedAndKeyboardState \
  -resultBundlePath /Volumes/DevVault/Xcode/DerivedData/NumPad-Task9/Task9-ManagedKiosk-StateCoverage-RED.xcresult \
  CODE_SIGNING_ALLOWED=YES -quiet

# Temporary Controllers/Studio/Task9DiscoverySentinel.swift present: 0/1.
xcodebuild test -workspace NumPad.xcworkspace -scheme NumPad -configuration Debug \
  -destination 'platform=iOS Simulator,id=37B2DC99-7B78-441D-9F09-220DA1D51CDD' \
  -only-testing:NumPadTests/IPadSettingsTests/test_studioAndOnboardingDirectLocalizationInventoryIsCompleteAndValid \
  -resultBundlePath /Volumes/DevVault/Xcode/DerivedData/NumPad-Task9/Task9-LocalizationDiscovery-RED.xcresult \
  CODE_SIGNING_ALLOWED=YES -quiet

# Before source-specific first-run store identification: signed 0/1.
xcodebuild test -workspace NumPad.xcworkspace -scheme NumPad -configuration Debug \
  -destination 'platform=iOS Simulator,id=5B976E69-A682-4406-BCFD-BCA93FC96352' \
  -only-testing:NumPadUITests/IPadStudioUITests/test_iPadFirstInstallProgressesThroughWowEnableHeightThenTryIt \
  -resultBundlePath /Volumes/DevVault/Xcode/DerivedData/NumPad-Task9/Task9-iPad-FirstRunUpsell-RED.xcresult \
  CODE_SIGNING_ALLOWED=YES -quiet
```

### Signed Studio UI matrix

| Device class | Explicit UDID | Result bundle | Result |
| --- | --- | --- | --- |
| Compact iPhone | `8B07966E-F68B-463C-81DE-956317AF67C5` | `Task9-Phone-Compact.xcresult` | 5 passed, 0 failed. |
| Standard iPhone | `37B2DC99-7B78-441D-9F09-220DA1D51CDD` | `Task9-Phone-Standard.xcresult` | 5 passed, 0 failed. |
| Large iPhone | `E4A85493-77E0-4454-93D9-AECFB2CE3C01` | `Task9-Phone-Large.xcresult` | 5 passed, 0 failed. |
| iPad | `5B976E69-A682-4406-BCFD-BCA93FC96352` | `Task9-iPad-Studio-GREEN.xcresult` | 6 passed, 0 failed. |

The exact signed UI commands were:

```sh
xcodebuild test -workspace NumPad.xcworkspace -scheme NumPad -configuration Debug \
  -destination 'platform=iOS Simulator,id=8B07966E-F68B-463C-81DE-956317AF67C5' \
  -only-testing:NumPadUITests/KeyboardStudioUITests \
  -resultBundlePath /Volumes/DevVault/Xcode/DerivedData/NumPad-Task9/Task9-Phone-Compact.xcresult \
  CODE_SIGNING_ALLOWED=YES -quiet

xcodebuild test -workspace NumPad.xcworkspace -scheme NumPad -configuration Debug \
  -destination 'platform=iOS Simulator,id=37B2DC99-7B78-441D-9F09-220DA1D51CDD' \
  -only-testing:NumPadUITests/KeyboardStudioUITests \
  -resultBundlePath /Volumes/DevVault/Xcode/DerivedData/NumPad-Task9/Task9-Phone-Standard.xcresult \
  CODE_SIGNING_ALLOWED=YES -quiet

xcodebuild test -workspace NumPad.xcworkspace -scheme NumPad -configuration Debug \
  -destination 'platform=iOS Simulator,id=E4A85493-77E0-4454-93D9-AECFB2CE3C01' \
  -only-testing:NumPadUITests/KeyboardStudioUITests \
  -resultBundlePath /Volumes/DevVault/Xcode/DerivedData/NumPad-Task9/Task9-Phone-Large.xcresult \
  CODE_SIGNING_ALLOWED=YES -quiet

xcodebuild test -workspace NumPad.xcworkspace -scheme NumPad -configuration Debug \
  -destination 'platform=iOS Simulator,id=5B976E69-A682-4406-BCFD-BCA93FC96352' \
  -only-testing:NumPadUITests/IPadStudioUITests \
  -resultBundlePath /Volumes/DevVault/Xcode/DerivedData/NumPad-Task9/Task9-iPad-Studio-GREEN.xcresult \
  CODE_SIGNING_ALLOWED=YES -quiet

xcodebuild test -workspace NumPad.xcworkspace -scheme NumPad -configuration Debug \
  -destination 'platform=iOS Simulator,id=5B976E69-A682-4406-BCFD-BCA93FC96352' \
  -only-testing:NumPadUITests/IPadStudioUITests/test_iPadFirstInstallProgressesThroughWowEnableHeightThenTryIt \
  -resultBundlePath /Volumes/DevVault/Xcode/DerivedData/NumPad-Task9/Task9-iPad-FirstRunUpsell-GREEN.xcresult \
  CODE_SIGNING_ALLOWED=YES -quiet
```

The signed iPad suite covers portrait, landscape, a narrow/compact-height state, first install,
existing user behavior, XL accessibility, and the permanent bottom dock / independently scrolling
upper canvas contract.

### Release builds

```sh
DEVELOPMENT_TEAM=NNRNHY2N8B CODE_SIGNING_ALLOWED=YES \
  xcodebuild build -workspace NumPad.xcworkspace -scheme NumPad -configuration Release \
  -destination 'generic/platform=iOS' \
  -resultBundlePath /Volumes/DevVault/Xcode/DerivedData/NumPad-Task9/Task9-Release-NumPad-FINAL.xcresult -quiet

DEVELOPMENT_TEAM=NNRNHY2N8B CODE_SIGNING_ALLOWED=YES \
  xcodebuild build -workspace NumPad.xcworkspace -scheme Keyboard -configuration Release \
  -destination 'generic/platform=iOS' \
  -resultBundlePath /Volumes/DevVault/Xcode/DerivedData/NumPad-Task9/Task9-Release-Keyboard-FINAL.xcresult -quiet
```

Both generic-device Release builds succeeded with zero errors and zero warnings. The team override
only supplies the existing project team to privacy-pod signing and did not alter repository files.

### Parse and static gates

- `plutil -lint` succeeded for all 74 `.strings`, plist, entitlement, and privacy-manifest files.
- 65 strings files were parsed; all 16 `Localizable.strings` catalogs have zero duplicate keys.
- The direct Studio/onboarding gate discovers its documented include roots, requires equality with
  the explicit 37-source set, and covers 131 keys across all 16 catalogs. It parses each table,
  rejects duplicate keys, checks `%@` placeholder parity, and fails on a relevant new source or an
  uncatalogued direct literal. Its exact current command is the combined 21/21 command above.
- Privacy policy copies (`docs/PrivacyPolicy` and `docs/PrivacyPolicy.md`) are identical.
- `UserPrefs.qwertyAutocorrect` remains default-off; QWERTY gate-off falls back to Numpad.
- Kiosk mode/height require Pro and rejected attempts do not mutate shared state.
- Studio analytics use only fixed source/surface/state/kind values, not typed, clipboard, snippet,
  or imported-profile content.

## Outstanding release gates and concerns

1. Native linguistic review is required for new Studio/onboarding catalog strings in all fifteen
   non-English locales. Current non-English entries are intentional English source fallbacks; key
   parity/parse success is not human-language approval.
2. Physical-device keyboard testing is required: Full Access, extension lifecycle/memory limits,
   haptics/sounds, globe switching, host-app entry, StoreKit purchase/restore Kiosk enforcement,
   iPad rotation, and Split View dock placement.
3. This task did not archive, distribute, upload, or submit the app to Apple.

## Final review remediation — `36db6ce2`

The final review found two important preview-truthfulness defects. `KeyboardStudioViewController`
now retains its root preview and quick-change card, refreshes both after a return, SettingsSync,
and StoreKit entitlement changes, and removes observers correctly. A controller regression drives
an existing root through a simulated quick-change return and verifies both the changed preview and
Letters action; a signed UI regression selects Calculations, returns, and verifies the existing
root says Math.

`StudioKeyboardPreviewModel` now treats QWERTY availability separately from its active page. The
Numpad-active form mirrors `KeyboardViewController.insertingQwertyPageKey(_:)` by placing ABC in
the existing bottom row and the pack switch directly after zero. Active QWERTY uses the shared
`QwertyTopStrip` and `QwertyLayout` source rows. Focused tests cover unavailable fallback,
available Numpad, active QWERTY, gate-off projection, and a projected custom configuration.
The dedicated runtime globe-key variation remains deliberately outside the preview API.

Validation at `36db6ce2`: the signed focused unit command listed in the release evidence covered
97 selected tests with 0 failures; the signed phone round-trip UI regression passed 1/1; signed
Debug `NumPad` build and the direct Studio/onboarding localization inventory also passed. No
archive, upload, TestFlight, App Store Connect, or Apple submission action occurred.
