# iPad keyboard width preview verification — 2026-07-30

Base reviewed: `bff592b306c21bcac031d06efbccaab99cbc6011`.

## Static and localization checks

- `find NumPad -name '*.strings' -print0 | xargs -0 -n1 plutil -lint`
- `find NumPad Keyboard -name '*.plist' -print0 | xargs -0 -n1 plutil -lint`
- `git diff --check`

All resource parses and the diff check passed. All 16 shipped `Localizable.strings` bundles now provide the width/layout labels, side labels, `Example`, `Setup preview`, and the composite VoiceOver preview summary. The non-English additions are machine-assisted/non-native translations and require native-language review before release (ar, de, es, fr, he, hi, it, ja, ko, nl, pl, pt-PT, ru, zh-Hans, zh-Hant).

Accessibility source and test checks confirm 44-point Studio tiles, selected trait plus checkmark/border (not color alone), percentage values, Dynamic Type scaling, and the non-interactive image-like dock summary. A focused regression caught and fixed percentage values being cleared when a width tile became selected.

## Tests

Fresh isolated unit invocation (new DerivedData directory because sandbox policy disallows deleting an existing one):

```sh
xcodebuild -workspace NumPad.xcworkspace -scheme NumPad \
  -destination 'platform=iOS Simulator,id=5B976E69-A682-4406-BCFD-BCA93FC96352' \
  -derivedDataPath /private/tmp/NumPad-iPadWidth-Unit-Only-DD-20260730-2301 \
  test -only-testing:NumPadTests \
  -resultBundlePath /private/tmp/NumPad-Task6-UnitOnly.xcresult
```

Result: 1,012 passed, 0 failed, 3 skipped (1,015 total). XCResult: `/private/tmp/NumPad-Task6-UnitOnly.xcresult`.

Focused regression RED/GREEN: `StudioDesignSystemTests/test_selectedWidthTileKeepsItsPercentageAccessibilityValue` failed before the fix and passed after it. Results: `/private/tmp/NumPad-Task6-WidthAccessibility-RED.xcresult`, `/private/tmp/NumPad-Task6-WidthAccessibility-GREEN.xcresult`.

iPad QA simulator (`QA-iPad-Pro-13`, `5B976E69-A682-4406-BCFD-BCA93FC96352`):

```sh
xcodebuild -workspace NumPad.xcworkspace -scheme NumPad \
  -destination 'platform=iOS Simulator,id=5B976E69-A682-4406-BCFD-BCA93FC96352' test \
  -only-testing:NumPadUITests/IPadStudioUITests/test_iPadWidthChoicesDefaultToFullAndDoNotChangeDockHeight \
  -only-testing:NumPadUITests/IPadStudioUITests/test_iPadLettersOffersStandardAndFullKeyboardWithConditionalSideControl \
  -only-testing:NumPadUITests/IPadStudioUITests/test_iPadStudioShowsOnePermanentDockAndNoLivePreviewLabelAcrossKeyboardEditors \
  -only-testing:NumPadUITests/IPadStudioUITests/test_iPadStudioLandscapeKeepsDockPinnedWhileChangingDestinationsAndOpeningAdvanced \
  -only-testing:NumPadUITests/IPadStudioUITests/test_iPadStudioPortraitShowsDockForEveryKeyboardHeight \
  -resultBundlePath /private/tmp/NumPad-Task6-iPadTargeted.xcresult
```

Result: 5 passed, 0 failed. Attachments include Compact, Comfortable, Medium, Wide, Full, Standard, Full-left, Full-right, landscape dock, and Small/Regular/Tall/Kiosk portrait states. Width changes preserved dock height; the vertical preset test preserved its documented ordering. XCResult: `/private/tmp/NumPad-Task6-iPadTargeted.xcresult`.

iPhone QA simulator (`QA-iPhone17`, `37B2DC99-7B78-441D-9F09-220DA1D51CDD`):

```sh
xcodebuild -workspace NumPad.xcworkspace -scheme NumPad \
  -destination 'platform=iOS Simulator,id=37B2DC99-7B78-441D-9F09-220DA1D51CDD' test \
  -only-testing:NumPadUITests/KeyboardStudioUITests/test_iPhoneOmitsIPadLayoutControlsAndKeepsPhoneControls \
  -resultBundlePath /private/tmp/NumPad-Task6-iPhoneTask6.xcresult
```

Result: 1 passed, 0 failed. It verifies all five width controls, both iPad layouts, and side selector are absent while existing phone height and Letters controls remain. XCResult: `/private/tmp/NumPad-Task6-iPhoneTask6.xcresult`.

## Builds

All succeeded: Debug QA iPad simulator, Debug QA iPhone simulator, Release `generic/platform=iOS Simulator`, and Release `generic/platform=iOS`. Commands used `xcodebuild -workspace NumPad.xcworkspace -scheme NumPad -configuration <Debug|Release> -destination <destination> build`; logs are in `/private/tmp/NumPad-Task6-build-*.log`.

## Visual/device limitations

The targeted iPad UI tests installed and launched the merged app on the QA iPad and retained screenshots in its XCResult. They exercise the permanent dock at every width and Standard/Full side state. The automated harness did not enable or raise the third-party keyboard extension, so a real-extension-to-dock visual comparison, floating keyboard, narrow Split View, RTL rendering, and connected-iPhone smoke are pending manual device QA. No risky signing changes were made.

No archive, upload, App Store submission, or Apple distribution action was performed.
