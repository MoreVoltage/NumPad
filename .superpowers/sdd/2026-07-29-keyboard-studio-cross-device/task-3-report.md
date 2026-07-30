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

## Fix Round 1 — stable setup-action accessibility identifier

Finding addressed: the disabled Keyboard status hero's visible `Open setup` action previously had
no stable accessibility identifier. The hero itself had an identifier, but that did not make the
internally-created action independently addressable by UI automation.

### RED

Command:

```sh
xcodebuild test -workspace NumPad.xcworkspace -scheme NumPad \
  -destination 'platform=iOS Simulator,id=37B2DC99-7B78-441D-9F09-220DA1D51CDD' \
  -only-testing:NumPadTests/StudioNavigationTests \
  -only-testing:NumPadTests/StudioDesignSystemTests \
  -derivedDataPath /tmp/NumPadStudioTask3FixDerivedData CODE_SIGNING_ALLOWED=YES
```

Result: expected RED. Compilation failed only because `StudioStatusHeroView` did not expose
`actionAccessibilityIdentifier`; both the design-system contract and disabled Keyboard surface
test referenced that missing API.

### GREEN

Same focused command → 14 tests passed, 0 failures. The tests prove that callers can set/read an
identifier on the visible hero action, that removing the action removes its accessibility artifact,
and that the disabled Keyboard Studio action uses `studio.keyboard.openSetup`.

### Signed build

```sh
xcodebuild build -workspace NumPad.xcworkspace -scheme NumPad \
  -destination 'platform=iOS Simulator,id=37B2DC99-7B78-441D-9F09-220DA1D51CDD' \
  -derivedDataPath /tmp/NumPadStudioTask3FixBuildDerivedData CODE_SIGNING_ALLOWED=YES
```

Result: `** BUILD SUCCEEDED **` with `Sign to Run Locally` for the app and validated embedded
Keyboard extension.

### Fix self-review

- `StudioStatusHeroView` exposes only an identifier property; its action button remains private.
- A removed/no-action state clears the property and removes the old action from the accessibility
  tree, so no stale focusable element remains.
- The Keyboard repair identifier is assigned only when the repair action exists.
- `git diff --check` is clean. The lifecycle demo-field minor was intentionally not changed.
