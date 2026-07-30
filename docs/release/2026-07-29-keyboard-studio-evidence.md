# Keyboard Studio verification evidence

## Scope and disposition

- Branch: `codex/keyboard-studio-ux`; reviewed range: `0f584a2c..HEAD`.
- Verification date: 2026-07-30. The workspace was `NumPad.xcworkspace` in the isolated
  `/Users/jamespikover/NumPad-studio` worktree.
- No archive-for-distribution, upload, TestFlight, App Store Connect, or Apple submission command
  was run. This is a release-candidate verification record, not a submission record.

## Executable gates

All commands used normal signing (`CODE_SIGNING_ALLOWED=YES`) and explicit simulator IDs where a
simulator was used.

| Gate | Command/result bundle | Result |
| --- | --- | --- |
| Full unit suite | `xcodebuild test -workspace NumPad.xcworkspace -scheme NumPad -configuration Debug -destination 'platform=iOS Simulator,id=37B2DC99-7B78-441D-9F09-220DA1D51CDD' -only-testing:NumPadTests -resultBundlePath /Volumes/DevVault/Xcode/DerivedData/NumPad-Task9/Task9-FullUnits-FINAL2.xcresult CODE_SIGNING_ALLOWED=YES -quiet` | 971 total; 968 passed; 3 skipped; 0 failed. |
| Targeted safety gate | `Task9-Safety-Gates.xcresult` | 39 passed; 0 failed; QWERTY fallback, Kiosk entitlement, onboarding-height, and Studio saved-setup coverage. |
| Compact iPhone Studio UI | `Task9-Phone-Compact.xcresult` on `8B07966E-F68B-463C-81DE-956317AF67C5` | 5 passed; 0 failed. |
| Standard iPhone Studio UI | `Task9-Phone-Standard.xcresult` on `37B2DC99-7B78-441D-9F09-220DA1D51CDD` | 5 passed; 0 failed. |
| Large iPhone Studio UI | `Task9-Phone-Large.xcresult` on `E4A85493-77E0-4454-93D9-AECFB2CE3C01` | 5 passed; 0 failed. |
| iPad Studio/onboarding UI | `Task9-iPad-Studio-GREEN.xcresult` on `5B976E69-A682-4406-BCFD-BCA93FC96352` | 6 passed; 0 failed: portrait, landscape, narrow-width/compact-height, permanent dock, first install, existing user, and XL accessibility. |
| App Release build | `DEVELOPMENT_TEAM=NNRNHY2N8B CODE_SIGNING_ALLOWED=YES xcodebuild build -workspace NumPad.xcworkspace -scheme NumPad -configuration Release -destination 'generic/platform=iOS' -resultBundlePath /Volumes/DevVault/Xcode/DerivedData/NumPad-Task9/Task9-Release-NumPad-FINAL.xcresult -quiet` | succeeded; 0 errors; 0 warnings. |
| Keyboard Release build | `DEVELOPMENT_TEAM=NNRNHY2N8B CODE_SIGNING_ALLOWED=YES xcodebuild build -workspace NumPad.xcworkspace -scheme Keyboard -configuration Release -destination 'generic/platform=iOS' -resultBundlePath /Volumes/DevVault/Xcode/DerivedData/NumPad-Task9/Task9-Release-Keyboard-FINAL.xcresult -quiet` | succeeded; 0 errors; 0 warnings. |

### Exact signed UI and safety commands

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

The iPad UI suite preserves the contract that the dock is a permanent bottom sibling while only
the upper canvas scrolls. The `DEVELOPMENT_TEAM` override supplies the app's already configured
team to CocoaPods privacy targets for generic-device signing; it changes neither project files nor
entitlements.

## Reproduced issues and remediation

1. Two managed-profile tests treated the Kiosk fixture as unentitled. The newly approved Kiosk
   Pro requirement correctly rejected it. The tests now supply a Pro-entitled Kiosk fixture;
   production authorization was not relaxed (`ba65327c`). The affected focused and full-unit
   gates passed.
2. The first-install iPad UI test expected the dock immediately after height selection, but the
   legitimate first-run value sheet could appear first. The test now returns from that sheet and
   verifies the dock (`3f86c110`). The full signed iPad suite passed 6/6.
3. Four direct Studio accessibility strings were absent from all 16 catalogs: `Keyboard preview:
   %@ key set, %@ theme, %@ height`, `LIVE KEYBOARD`, `Live keyboard preview`, and `Visual preview
   of the selected keyboard.` A focused localization test first failed, the missing fallback
   entries were added, and it passed (`5316439b`; `Task9-Localization-GREEN.xcresult`, 1/1).
4. `ProfileImportCoordinatorTests.test_importedKioskRetainsEnforceableSemanticKind` predated the
   July 30 Pro-only import guard and silently used the unentitled default. Its focused reproduction
   failed with `saveFailed` / `Kiosk mode requires Pro`. It now prepares then stores the profile
   with `proEntitled: true` (`37cdc554`; `Task9-ProfileImport-GREEN.xcresult`, 1/1). Separate
   coverage continues to verify that an unentitled Kiosk import is not saved.
5. Independent review required a coordinator-level negative Kiosk regression. The new test begins
   from an applied standard managed profile, requests built-in Kiosk while unentitled, and proves
   `.rejected` preserves the active profile, every live keyboard setting, last-good digest, and
   notification count. Removing the production guard produced RED 0/1
   (`Task9-ManagedKiosk-RED.xcresult`); restoring it passed all 20 coordinator tests
   (`Task9-ManagedCoordinator-GREEN.xcresult`).
6. The iPad onboarding test previously trusted any `NumPad Pro` navigation bar. The first-run store
   now exposes `store.first-run-upsell` only for `source == "first_run"`; the test requires that
   identifier before Back, then requires the iPad Studio workspace and permanent dock. Signed RED
   was 0/1 and signed GREEN was 1/1 on the explicit iPad UDID
   (`Task9-iPad-FirstRunUpsell-{RED,GREEN}.xcresult`).
7. The localization inventory is now a checked-in XCTest with the exact 37-source list. A temporary
   uncatalogued direct literal produced RED 0/1; after its removal the gate passed 1/1
   (`Task9-LocalizationInventory-{RED,GREEN}.xcresult`).

## Static, privacy, entitlement, and accessibility audit

- `plutil -lint` parsed 74 `.strings`, plist, entitlement, and privacy-manifest files; 65 were
  strings files. All 16 app `Localizable.strings` catalogs have zero duplicate keys.
- `IPadSettingsTests.test_studioAndOnboardingDirectLocalizationInventoryIsCompleteAndValid`
  contains the exact 37-source inventory, extracts exactly 131 unique direct keys, parses all 16
  app catalogs, rejects duplicate declarations, verifies nonempty values and `%@` placeholder
  parity, and fails when a source gains an uncatalogued direct literal. Reproduce it with:

```sh
xcodebuild test -workspace NumPad.xcworkspace -scheme NumPad -configuration Debug \
  -destination 'platform=iOS Simulator,id=37B2DC99-7B78-441D-9F09-220DA1D51CDD' \
  -only-testing:NumPadTests/IPadSettingsTests/test_studioAndOnboardingDirectLocalizationInventoryIsCompleteAndValid \
  -resultBundlePath /Volumes/DevVault/Xcode/DerivedData/NumPad-Task9/Task9-LocalizationInventory-GREEN.xcresult \
  CODE_SIGNING_ALLOWED=YES -quiet
```
- `docs/PrivacyPolicy` and `docs/PrivacyPolicy.md` are byte-identical.
- `UserPrefs.qwertyAutocorrect` remains default-off. `KeyboardProfileApplier` sends an unavailable
  QWERTY page to Numpad with `.qwertyPageLocked`; it does not persist an unsafe page choice.
- Both application and profile-import paths check `KioskModeAccess.allows(..., proEntitled:)` and
  reject a locked Kiosk setup before shared-state mutation. The test suite covers both the entitled
  and unentitled paths.
- Diff review found no Glide code, promise, or marketing copy added in `0f584a2c..HEAD`.
- New Studio analytics use fixed source/surface/state/kind values. The import event contains only
  `source: studio`; no typed value, clipboard, snippet, or imported setup content is passed.
- Studio controls use Dynamic Type, directional margins, minimum 44-point targets, non-color-only
  state cues, and VoiceOver identifiers/labels. The automatic-appearance state includes an
  explanatory disabled treatment.

## Remaining release gates

Native linguistic approval has not been performed. The English fallback entries for all new
Studio/onboarding strings—including the four preview/dock entries above—need review in `ar`, `de`,
`es`, `fr`, `he`, `hi`, `it`, `ja`, `ko`, `nl`, `pl`, `pt-PT`, `ru`, `zh-Hans`, and `zh-Hant`.

Physical-device verification remains required before submission: enable the keyboard with Full
Access on real iPhone and iPad hardware; verify extension lifecycle/memory behavior, haptics and
sound, keyboard switching, Kiosk purchase/restore enforcement, dock positioning through rotation
and Split View, and actual keyboard input in host apps. Simulator coverage is not a substitute for
those extension checks.
