# Task 3 report — iPhone Keyboard Studio shell

## Files

- Added `NumPad/Controllers/Studio/StudioTabBarController.swift`
- Added `NumPad/Controllers/Studio/StudioNavigationFactory.swift`
- Added `NumPad/Controllers/Studio/KeyboardStudioViewController.swift`
- Added `NumPad/Controllers/Studio/FeaturesStudioViewController.swift`
- Added `NumPad/Controllers/Studio/HelpStudioViewController.swift`
- Added `NumPadTests/StudioNavigationTests.swift`
- Updated `NumPad/Controllers/Base/ViewController.swift`
- Updated `NumPadTests/DeepLinkRouterTests.swift`
- Updated `NumPadTests/IPadLaunchOrchestrationTests.swift`
- Registered all new Swift files through `scripts/add_sources.rb` (no hand-editing of the project file).

## RED

Command:

```sh
xcodebuild test -workspace NumPad.xcworkspace -scheme NumPad \
  -destination 'platform=iOS Simulator,id=37B2DC99-7B78-441D-9F09-220DA1D51CDD' \
  -only-testing:NumPadTests/StudioNavigationTests \
  -only-testing:NumPadTests/DeepLinkRouterTests \
  -derivedDataPath /tmp/NumPadStudioTask3DerivedData CODE_SIGNING_ALLOWED=YES
```

Result: expected RED. The test target failed to compile because
`StudioNavigationFactory` and `ViewController.studioTabs` did not exist. This proves the new
navigation and lifecycle behaviors were missing before implementation.

## GREEN

Command:

```sh
xcodebuild test -workspace NumPad.xcworkspace -scheme NumPad \
  -destination 'platform=iOS Simulator,id=37B2DC99-7B78-441D-9F09-220DA1D51CDD' \
  -only-testing:NumPadTests/StudioNavigationTests \
  -only-testing:NumPadTests/DeepLinkRouterTests \
  -only-testing:NumPadTests/IPadLaunchOrchestrationTests \
  -derivedDataPath /tmp/NumPadStudioTask3DerivedData CODE_SIGNING_ALLOWED=YES
```

Result: 30 tests passed, 0 failures. Coverage includes exact three-tab composition, default
Keyboard selection, navigation wrapping, Dashboard absence, Advanced presentation, retained iPad
lifecycle ownership, and Store/profile/DEBUG guide/DEBUG height routing through a selected tab.

`DeepLinkRouter.swift` was not changed: the compatibility tests confirmed its existing selected-tab
recursion works with navigation-wrapped Studio tabs.

## Signed build and smoke

- Signed Debug simulator build: `xcodebuild build -workspace NumPad.xcworkspace -scheme NumPad -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/NumPadStudioTask3BuildDerivedData CODE_SIGNING_ALLOWED=YES` → `** BUILD SUCCEEDED **`.
- Simulator launch: `xcrun simctl launch --terminate-running-process 37B2DC99-7B78-441D-9F09-220DA1D51CDD com.morevoltage.NumPad -skipOnboarding` → PID 82932.
- Settled screenshot: `/tmp/numpad-task3-studio-shell-settled.png` shows the Keyboard Studio tab,
  gear, status hero, live preview, Try It field, quick changes, and only Keyboard/Features/Help tabs.

## Self-review

- Phone-only `installContentShell()` branch now embeds the Studio tab shell; splash, onboarding,
  pending deep-link drain, foreground observers, StoreKit startup, and the iPad split branch stay in
  the lifecycle coordinator unchanged.
- All three visible tabs are navigation-wrapped. The Advanced gear presents a modal navigation
  surface with working Saved setups, Kiosk mode, and Move setups routes; no Dashboard or Pro tab is
  exposed.
- Skeleton actions push existing working controllers; stable accessibility identifiers cover tabs,
  tab roots, quick changes, Help/Features actions, and Advanced actions.
- Analytics only records navigation source/surface (`studio_opened`, `advanced_opened`), never typed
  or imported content.
- `git diff --check` is clean.

## Concerns

- This task intentionally leaves detailed Advanced content and focused quick-change redesign to
  Tasks 4–5; its routes currently use the established controllers.
- The broader suite and generic Release targets remain final integration gates owned by the overall
  phase; this task ran the required focused signed simulator evidence.
