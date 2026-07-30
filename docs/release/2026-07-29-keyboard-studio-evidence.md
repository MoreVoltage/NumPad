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
| Full unit suite at tested code commit `9736f4cb` | `xcodebuild test -workspace NumPad.xcworkspace -scheme NumPad -configuration Debug -destination 'platform=iOS Simulator,id=37B2DC99-7B78-441D-9F09-220DA1D51CDD' -only-testing:NumPadTests -resultBundlePath /Volumes/DevVault/Xcode/DerivedData/NumPad-Task9/Task9-FullUnits-Review2-9736f4cb.xcresult CODE_SIGNING_ALLOWED=YES -quiet` | 972 total; 969 passed; 3 skipped; 0 failed. |
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
   entries were added, and the current self-discovering localization gate passes (`5316439b`).
4. `ProfileImportCoordinatorTests.test_importedKioskRetainsEnforceableSemanticKind` predated the
   July 30 Pro-only import guard and silently used the unentitled default. Its focused reproduction
   failed with `saveFailed` / `Kiosk mode requires Pro`. It now prepares then stores the profile
   with `proEntitled: true` (`37cdc554`). The current full signed unit suite covers this test, and
   separate coverage continues to verify that an unentitled Kiosk import is not saved.
5. Independent review required a coordinator-level negative Kiosk regression. The new test begins
   from an applied standard managed profile, requests built-in Kiosk while unentitled, and proves
   `.rejected` preserves the active profile, complete profile-store snapshot, all live and
   transaction settings (including Kiosk session keys), resolved Kiosk policy/session, all four
   applied/digest metadata values, editing lock, and the injected SettingsSync notification count.
   The generic diagnostic intentionally changes and exactly one in-process `stateDidChange` is
   expected. Guard-removed RED was 0/1; restored coordinator plus localization GREEN is 21/21.
6. The iPad onboarding test previously trusted any `NumPad Pro` navigation bar. The first-run store
   now exposes `store.first-run-upsell` only for `source == "first_run"`; the test requires that
   identifier before Back, then requires the iPad Studio workspace and permanent dock. Signed RED
   was 0/1 and signed GREEN was 1/1 on the explicit iPad UDID.
7. The localization XCTest now discovers sources from its documented include roots and compares
   the normalized result to the explicit 37-source set before extracting literals. A temporary
   extra discovered Studio file produced RED 0/1; after its removal the combined gate passed 21/21.

### Current follow-up and non-release diagnostic commands

The current combined follow-up is a release verification gate and passed 21/21:

```sh
xcodebuild test -workspace NumPad.xcworkspace -scheme NumPad -configuration Debug \
  -destination 'platform=iOS Simulator,id=37B2DC99-7B78-441D-9F09-220DA1D51CDD' \
  -only-testing:NumPadTests/ManagedProfileCoordinatorTests \
  -only-testing:NumPadTests/IPadSettingsTests/test_studioAndOnboardingDirectLocalizationInventoryIsCompleteAndValid \
  -resultBundlePath /Volumes/DevVault/Xcode/DerivedData/NumPad-Task9/Task9-Review2-Focused-GREEN.xcresult \
  CODE_SIGNING_ALLOWED=YES -quiet
```

The following RED bundles are non-release diagnostic artifacts. Each command was run against the
temporarily broken condition stated; none represents the final code state:

```sh
# Guard temporarily removed: failed 0/1 with eight state-preservation assertions.
xcodebuild test -workspace NumPad.xcworkspace -scheme NumPad -configuration Debug \
  -destination 'platform=iOS Simulator,id=37B2DC99-7B78-441D-9F09-220DA1D51CDD' \
  -only-testing:NumPadTests/ManagedProfileCoordinatorTests/test_unentitledBuiltInKioskRejectionPreservesLastGoodManagedAndKeyboardState \
  -resultBundlePath /Volumes/DevVault/Xcode/DerivedData/NumPad-Task9/Task9-ManagedKiosk-StateCoverage-RED.xcresult \
  CODE_SIGNING_ALLOWED=YES -quiet

# Temporary Controllers/Studio/Task9DiscoverySentinel.swift present: failed 0/1.
xcodebuild test -workspace NumPad.xcworkspace -scheme NumPad -configuration Debug \
  -destination 'platform=iOS Simulator,id=37B2DC99-7B78-441D-9F09-220DA1D51CDD' \
  -only-testing:NumPadTests/IPadSettingsTests/test_studioAndOnboardingDirectLocalizationInventoryIsCompleteAndValid \
  -resultBundlePath /Volumes/DevVault/Xcode/DerivedData/NumPad-Task9/Task9-LocalizationDiscovery-RED.xcresult \
  CODE_SIGNING_ALLOWED=YES -quiet

# Before `store.first-run-upsell` existed: signed failure 0/1.
xcodebuild test -workspace NumPad.xcworkspace -scheme NumPad -configuration Debug \
  -destination 'platform=iOS Simulator,id=5B976E69-A682-4406-BCFD-BCA93FC96352' \
  -only-testing:NumPadUITests/IPadStudioUITests/test_iPadFirstInstallProgressesThroughWowEnableHeightThenTryIt \
  -resultBundlePath /Volumes/DevVault/Xcode/DerivedData/NumPad-Task9/Task9-iPad-FirstRunUpsell-RED.xcresult \
  CODE_SIGNING_ALLOWED=YES -quiet
```

## Static, privacy, entitlement, and accessibility audit

- `plutil -lint` parsed 74 `.strings`, plist, entitlement, and privacy-manifest files; 65 were
  strings files. All 16 app `Localizable.strings` catalogs have zero duplicate keys.
- `IPadSettingsTests.test_studioAndOnboardingDirectLocalizationInventoryIsCompleteAndValid`
  discovers every source matching its documented include rule, requires that normalized set to
  equal the explicit 37-source inventory, extracts exactly 131 unique direct keys, parses all 16
  app catalogs, rejects duplicate declarations, verifies nonempty values and `%@` placeholder
  parity, and fails when a relevant source or uncatalogued direct literal is added. Reproduce it
  as part of the 21/21 combined follow-up command above.
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

## Final review remediation — `36db6ce2`

The final review found that the phone Studio root retained a stale preview and static Letters row
after returning from a quick change, and that the preview represented QWERTY as an extra `ABC` row
instead of the extension's actual page model. The remediation keeps the root's preview/card
references, refreshes them on appearance, `SettingsSync`, and StoreKit entitlement notifications,
and removes those observers correctly. It uses shared `QwertyTopStrip` and `QwertyLayout` sources
for a bounded active-QWERTY preview. A QWERTY-available Numpad uses the extension's existing
bottom-row rule: `ABC` leads and the pack switch is immediately after `0`. The runtime-only
dedicated-globe (`needsSwitchKey`) variation remains intentionally unmodeled, as previously
documented.

| Gate | Result |
| --- | --- |
| Focused preview/controller/layout/profile/entitlement unit gate | 97 selected tests, 0 failed: `xcodebuild test -quiet -workspace NumPad.xcworkspace -scheme NumPad -configuration Debug -destination 'platform=iOS Simulator,id=37B2DC99-7B78-441D-9F09-220DA1D51CDD' -only-testing:NumPadTests/StudioKeyboardPreviewTests -only-testing:NumPadTests/KeyboardStudioRefreshTests -only-testing:NumPadTests/StudioKeySetCatalogTests -only-testing:NumPadTests/StudioSettingsWriterTests -only-testing:NumPadTests/QwertyLayoutTests -only-testing:NumPadTests/QwertyGatingTests -only-testing:NumPadTests/KeyboardProfileApplierTests -only-testing:NumPadTests/CustomKeyboardLayoutTests -only-testing:NumPadTests/CustomKeyboardConfigTests -only-testing:NumPadTests/CustomKeyboardEntitlementTests CODE_SIGNING_ALLOWED=YES` |
| Signed phone UI regression | 1 passed: `xcodebuild test -quiet -workspace NumPad.xcworkspace -scheme NumPad -configuration Debug -destination 'platform=iOS Simulator,id=37B2DC99-7B78-441D-9F09-220DA1D51CDD' -only-testing:NumPadUITests/KeyboardStudioUITests/test_quickChangeRoundTripRefreshesTheExistingRootPreview CODE_SIGNING_ALLOWED=YES` |
| Signed Debug compile | `NumPad` and `Keyboard.appex` built successfully: `xcodebuild build -quiet -workspace NumPad.xcworkspace -scheme NumPad -configuration Debug -destination 'platform=iOS Simulator,id=37B2DC99-7B78-441D-9F09-220DA1D51CDD' CODE_SIGNING_ALLOWED=YES` |
| Studio localization inventory | 1 passed: `NumPadTests/IPadSettingsTests/test_studioAndOnboardingDirectLocalizationInventoryIsCompleteAndValid` on the same signed phone simulator. No new localizable sentence was introduced; shared keyboard controls/product labels are reused. |

This remediation did not upload, archive for distribution, distribute, or submit the app to Apple.

## Final coordinator verification — `5399976c`

The primary coordinator reran the full signed unit suite and both generic-device Release schemes
from the final production tree after the preview remediation:

```sh
xcodebuild test -workspace NumPad.xcworkspace -scheme NumPad -configuration Debug \
  -destination 'platform=iOS Simulator,id=37B2DC99-7B78-441D-9F09-220DA1D51CDD' \
  -only-testing:NumPadTests \
  -resultBundlePath /Volumes/DevVault/Xcode/DerivedData/NumPad-FinalRoot/FinalRoot-FullUnits-5399976c.xcresult \
  CODE_SIGNING_ALLOWED=YES -quiet

DEVELOPMENT_TEAM=NNRNHY2N8B CODE_SIGNING_ALLOWED=YES \
  xcodebuild build -workspace NumPad.xcworkspace -scheme NumPad -configuration Release \
  -destination 'generic/platform=iOS' \
  -resultBundlePath /Volumes/DevVault/Xcode/DerivedData/NumPad-FinalRoot/FinalRoot-Release-NumPad-5399976c.xcresult \
  -quiet

DEVELOPMENT_TEAM=NNRNHY2N8B CODE_SIGNING_ALLOWED=YES \
  xcodebuild build -workspace NumPad.xcworkspace -scheme Keyboard -configuration Release \
  -destination 'generic/platform=iOS' \
  -resultBundlePath /Volumes/DevVault/Xcode/DerivedData/NumPad-FinalRoot/FinalRoot-Release-Keyboard-5399976c.xcresult \
  -quiet
```

- Full units: 977 total, 974 passed, 3 skipped, 0 failed.
- NumPad Release: succeeded with 0 errors and 2 warnings: the pre-existing
  `UIButton.contentEdgeInsets` deprecation in `SnippetEditorViewController` and a local missing
  Metal toolchain search path.
- Keyboard Release: succeeded with 0 errors and 1 warning: the same local missing Metal toolchain
  search path.

These final-tree results supersede the earlier zero-warning incremental Release bundles for
handoff status. No archive, upload, distribution, TestFlight, App Store Connect, or Apple
submission action was performed.
