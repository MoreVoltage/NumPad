# Evidence log — usability / QWERTY / iPad / kiosk implementation
# Branch: grok/usability-qwerty-ipad-kiosk
# Baseline: d9606559

## Task 1
- Files added via scripts/add_xcode_files.rb
- Status: implementing

## Task 1 — DONE @ 77332c13
- Focused: 3/3 pass (Task1-KeyboardStatus.xcresult)
- Full unit: 669 tests, 0 failures (Task1-FullUnit.xcresult)
- Destination: id=3A037648-417A-4B4B-8180-D06539B28FF3 (DevVault iPhone 17, OS 26.5)
- Deviation: QwertySetup keeps Off fallback via `?? "Off"` when detail is nil

## Task 2 — DONE @ 09568ffe
- Focused: BehaviorSetting + HomeSettingsModel 4/4 pass
- Store `.controls` removed; iCloud moved to TypingBehaviorViewController
- Deviation: Home includes layout switch destinations (numberOrder/roundedCorners/grid) plus placeholder Profiles/Kiosk until Tasks 5/15

## Task 3 — DONE
- KeyboardProfileTests 5/5 pass; NumPad build succeeded with KeyboardLayoutPreferences in both targets
- Early-added qwertyAutocorrect/Suggestions/DoubleSpacePeriod prefs (default true) so schema/applier can write them before Task 6 UI

## Task 4 — DONE
- Store/Applier/Migration tests: 7/7 pass
- AppDelegate runs KeyboardProfileMigration.runIfNeeded after RC start
- CloudSync syncedKeys += keyboardProfiles + activeKeyboardProfileID
