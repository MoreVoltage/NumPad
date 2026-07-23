# NumPad Usability, QWERTY, iPad, and Kiosk Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a safer, easier-to-configure NumPad with versioned Profiles, a credible tap-typing QWERTY page, an adaptive iPad companion app, and a complete kiosk provisioning mode.

**Architecture:** Add a typed Profiles domain and transactional app-group applier, then make phone and iPad settings consume the same models through different UIKit navigation shells. Keep keyboard-extension changes small and pure at their core: preferences, geometry, correction confidence, punctuation, repeat/cursor policies, and kiosk session policy are unit-testable value types; UIKit hosts only render them and forward events.

**Tech Stack:** Swift, UIKit, StoreKit 2, `UITextChecker`, `LocalAuthentication`, app-group `UserDefaults`, Darwin notifications, iCloud KVS, XCTest/XCUITest, CocoaPods, Xcode workspace.

## Global Constraints

- Build and test `NumPad.xcworkspace`, never `NumPad.xcodeproj`.
- Preserve iOS 15.0 as the minimum deployment target.
- Keep the app UIKit-first; existing SwiftUI custom-editor code may remain but is not the pattern for new settings screens.
- Do not add a dependency, network typing service, backend, SDK, widget, or new target.
- Keep `FeatureFlags.qwertyGlideTyping` dark and forced off in App Store builds.
- Do not wire `QwertyNextWordPredictor` or `QwertySymSpellCorrector` into the Keyboard target.
- Never persist or emit typed text, clipboard text, snippets, learned words, word hashes, touch coordinates, host app identifiers, or field contents.
- Preserve unrelated work and never modify, stage, delete, or commit `Auto-Company/`.
- Add every new Swift file to the correct Xcode targets: shared keyboard-domain files to both `NumPad` and `Keyboard`; app controllers and `LocalAuthentication` code to `NumPad` only; tests to `NumPadTests` or `NumPadUITests`.
- Use `NSLocalizedString` for every user-facing string and add English source entries before the localization sweep.
- Apply a profile as one transaction and call `SettingsSync.post()` exactly once after all app-group writes.
- Do not archive, upload, distribute, submit to App Store Connect, or change Apple release state. Completion hands the branch to Codex for review.

## Delivery Waves

1. **Wave A — Safety and foundations:** Tasks 1–5.
2. **Wave B — QWERTY tap-typing quality:** Tasks 6–12.
3. **Wave C — iPad and kiosk:** Tasks 13–16.
4. **Wave D — privacy, localization, and release evidence:** Tasks 17–18.

Do not start a later wave while an earlier wave has failing tests or an unresolved review finding.

## File Map

### New shared/app-domain files

- `NumPad/Libraries/KeyboardStatusPresentation.swift` — pure enablement display and demo-field inset helpers.
- `NumPad/Libraries/Settings/BehaviorSetting.swift` — canonical behavior-setting catalog used outside the store.
- `NumPad/Libraries/Settings/HomeSettingsModel.swift` — section/row/destination model for phone and iPad.
- `NumPad/Libraries/Profiles/KeyboardProfile.swift` — versioned profile schema and kiosk policy.
- `NumPad/Libraries/Profiles/KeyboardProfileStore.swift` — app-group persistence and corruption handling.
- `NumPad/Libraries/Profiles/KeyboardProfileFactory.swift` — built-in templates and current-settings snapshot.
- `NumPad/Libraries/Profiles/KeyboardProfileApplier.swift` — validation, entitlement fallback, transactional writes.
- `NumPad/Libraries/Profiles/KeyboardProfileMigration.swift` — idempotent first-run migration.
- `NumPad/Libraries/Profiles/KeyboardProfileDocument.swift` — validated `.numpadprofile` envelope.
- `NumPad/Libraries/Profiles/ManagedProfileConfiguration.swift` — MDM dictionary parser.
- `NumPad/Libraries/KeyboardLayoutPreferences.swift` — shared `QwertyLayoutMode` and `NumpadPlacement`.

### New app UI files

- `NumPad/Controllers/TypingBehaviorViewController.swift`
- `NumPad/Controllers/ProfilesViewController.swift`
- `NumPad/Controllers/ProfileEditorViewController.swift`
- `NumPad/Controllers/ProfileImportCoordinator.swift`
- `NumPad/Controllers/DashboardViewController.swift`
- `NumPad/Controllers/IPadSettingsSplitViewController.swift`
- `NumPad/Controllers/KioskProvisioningViewController.swift`
- `NumPad/Controllers/PersonalDictionaryViewController.swift`

### New QWERTY/shared logic

- `NumPad/Libraries/Qwerty/QwertyCorrectionConfidence.swift`
- `NumPad/Libraries/Qwerty/QwertyPunctuationRules.swift`
- `NumPad/Libraries/Qwerty/QwertyAlternates.swift`
- `NumPad/Libraries/Qwerty/QwertyBackspacePolicy.swift`
- `NumPad/Libraries/Qwerty/QwertyCursorAccumulator.swift`
- `NumPad/Libraries/Qwerty/QwertyPersonalizationContext.swift`
- `NumPad/Libraries/Qwerty/QwertyLayoutGeometry.swift`
- `NumPad/Libraries/Kiosk/KioskReadiness.swift`
- `NumPad/Libraries/Kiosk/KioskSessionPolicy.swift`
- `NumPad/Libraries/TypingQualityCounters.swift`
- `Keyboard/Views/QwertyAlternateMenuView.swift`

### New tests

- `NumPadTests/KeyboardStatusPresentationTests.swift`
- `NumPadTests/HomeSettingsModelTests.swift`
- `NumPadTests/BehaviorSettingTests.swift`
- `NumPadTests/KeyboardProfileTests.swift`
- `NumPadTests/KeyboardProfileStoreTests.swift`
- `NumPadTests/KeyboardProfileApplierTests.swift`
- `NumPadTests/KeyboardProfileMigrationTests.swift`
- `NumPadTests/KeyboardProfileDocumentTests.swift`
- `NumPadTests/ManagedProfileConfigurationTests.swift`
- `NumPadTests/QwertyPreferencesTests.swift`
- `NumPadTests/QwertyCorrectionConfidenceTests.swift`
- `NumPadTests/QwertyPunctuationRulesTests.swift`
- `NumPadTests/QwertyAlternatesTests.swift`
- `NumPadTests/QwertyBackspacePolicyTests.swift`
- `NumPadTests/QwertyCursorAccumulatorTests.swift`
- `NumPadTests/QwertyPersonalizationContextTests.swift`
- `NumPadTests/QwertyLayoutGeometryTests.swift`
- `NumPadTests/KioskReadinessTests.swift`
- `NumPadTests/KioskSessionPolicyTests.swift`
- `NumPadTests/TypingQualityCountersTests.swift`
- `NumPadUITests/IPadSettingsTests.swift`
- `NumPadUITests/ProfileAndKioskTests.swift`

---

### Task 1: Correct status reporting and home-field layout

**Files:**
- Create: `NumPad/Libraries/KeyboardStatusPresentation.swift`
- Modify: `NumPad/Controllers/HomeViewController.swift:140-147`
- Modify: `NumPad/Controllers/QwertySetupViewController.swift:103-112`
- Modify: `NumPad/Controllers/Base/ViewController.swift:32-58, 384-420`
- Test: `NumPadTests/KeyboardStatusPresentationTests.swift`

**Interfaces:**
- Produces: `KeyboardStatusPresentation.detail(isEnabled:) -> String?`
- Produces: `HomeDemoLayout.contentInset(fieldHeight:verticalMargin:) -> CGFloat`

- [ ] **Step 1: Write failing pure tests**

```swift
final class KeyboardStatusPresentationTests: XCTestCase {
    func test_disabledHasNoOnDetail() {
        XCTAssertNil(KeyboardStatusPresentation.detail(isEnabled: false))
    }

    func test_enabledHasOnDetail() {
        XCTAssertNotNil(KeyboardStatusPresentation.detail(isEnabled: true))
    }

    func test_demoClearanceIncludesFieldAndBothMargins() {
        XCTAssertEqual(HomeDemoLayout.contentInset(fieldHeight: 44, verticalMargin: 16), 76)
    }
}
```

- [ ] **Step 2: Run the focused tests and confirm compile failure**

```bash
xcodebuild test -workspace NumPad.xcworkspace -scheme NumPad \
  -destination 'platform=iOS Simulator,name=DevVault iPhone 17' \
  -derivedDataPath /Volumes/DevVault/Xcode/DerivedData/NumPad-Grok \
  -only-testing:NumPadTests/KeyboardStatusPresentationTests CODE_SIGNING_ALLOWED=NO
```

Expected: failure because `KeyboardStatusPresentation` and `HomeDemoLayout` do not exist.

- [ ] **Step 3: Implement the pure helpers**

```swift
import Foundation
import CoreGraphics

enum KeyboardStatusPresentation {
    static func detail(isEnabled: Bool) -> String? {
        isEnabled ? NSLocalizedString("On", comment: "Enabled setting status") : nil
    }
}

enum HomeDemoLayout {
    static func contentInset(fieldHeight: CGFloat, verticalMargin: CGFloat) -> CGFloat {
        fieldHeight + 2 * verticalMargin
    }
}
```

- [ ] **Step 4: Replace both `!= nil` checks and reserve the field clearance at rest**

Use `KeyboardStatusPresentation.detail(isEnabled: Keyboard.isKeyboardEnabled)` in both controllers. Set the table’s base `contentInset.bottom` and scroll-indicator inset to 76 immediately after constructing the field; while the keyboard is visible, add keyboard overlap to that base rather than replacing it.

- [ ] **Step 5: Run focused and full unit tests**

Expected: focused tests pass; full suite remains at least 666 tests with zero failures.

- [ ] **Step 6: Commit**

```bash
git add NumPad/Libraries/KeyboardStatusPresentation.swift \
  NumPad/Controllers/HomeViewController.swift \
  NumPad/Controllers/QwertySetupViewController.swift \
  NumPad/Controllers/Base/ViewController.swift \
  NumPadTests/KeyboardStatusPresentationTests.swift NumPad.xcodeproj/project.pbxproj
git commit -m "fix: correct keyboard status and home input clearance"
```

---

### Task 2: Separate settings from commerce and define the new information architecture

**Files:**
- Create: `NumPad/Libraries/Settings/BehaviorSetting.swift`
- Create: `NumPad/Libraries/Settings/HomeSettingsModel.swift`
- Create: `NumPad/Controllers/TypingBehaviorViewController.swift`
- Modify: `NumPad/Controllers/HomeViewController.swift`
- Modify: `NumPad/Controllers/StoreViewController.swift`
- Test: `NumPadTests/BehaviorSettingTests.swift`
- Test: `NumPadTests/HomeSettingsModelTests.swift`

**Interfaces:**
- Produces: `BehaviorSetting: String, CaseIterable`
- Produces: `HomeSettingsModel.sections(fullKeyboardVisible:isPad:) -> [HomeSection]`
- Produces: `SettingsDestination`, reused by the iPad split controller in Task 13.

- [ ] **Step 1: Write catalog and section tests**

```swift
func test_behaviorCatalogHasNoDuplicateIDs() {
    XCTAssertEqual(Set(BehaviorSetting.allCases.map(\.rawValue)).count,
                   BehaviorSetting.allCases.count)
}

func test_storeIsNotTypingBehaviorDestination() {
    let sections = HomeSettingsModel.sections(fullKeyboardVisible: true, isPad: false)
    let typing = sections.first { $0.id == .typingBehavior }
    XCTAssertTrue(typing?.rows.contains(.typingBehavior) == true)
    XCTAssertFalse(typing?.rows.contains(.pro) == true)
}

func test_qwertyRowObeysRolloutVisibility() {
    let hidden = HomeSettingsModel.sections(fullKeyboardVisible: false, isPad: false)
    XCTAssertFalse(hidden.flatMap(\.rows).contains(.qwerty))
}
```

- [ ] **Step 2: Define the canonical behavior enum**

```swift
enum BehaviorSetting: String, CaseIterable {
    case haptics, keyClickSound, repurposeNextKey, inlineCalculator
    case liveMathPreview, cursorControls, smartPackDefaulting, resultTape

    var isOn: Bool {
        switch self {
        case .haptics: return UserPrefs.hapticsEnabled
        case .keyClickSound: return UserPrefs.soundEnabled
        case .repurposeNextKey: return UserPrefs.repurposeNextKey
        case .inlineCalculator: return UserPrefs.inlineCalculator
        case .liveMathPreview: return UserPrefs.liveMathPreview
        case .cursorControls: return UserPrefs.cursorControls
        case .smartPackDefaulting: return UserPrefs.smartPackDefaulting
        case .resultTape: return UserPrefs.lastResultTape
        }
    }

    func set(_ value: Bool) {
        switch self {
        case .haptics: UserPrefs.hapticsEnabled = value
        case .keyClickSound: UserPrefs.soundEnabled = value
        case .repurposeNextKey: UserPrefs.repurposeNextKey = value
        case .inlineCalculator: UserPrefs.inlineCalculator = value
        case .liveMathPreview: UserPrefs.liveMathPreview = value
        case .cursorControls: UserPrefs.cursorControls = value
        case .smartPackDefaulting: UserPrefs.smartPackDefaulting = value
        case .resultTape: UserPrefs.lastResultTape = value
        }
        SettingsSync.post()
        Analytics.logEvent(name: "behavior_setting_changed",
                           attributes: ["setting": rawValue, Analytics.ParameterValue: value])
    }
}
```

The setter posts `SettingsSync` and logs one stable analytics event. Do not retain closure-based rows in the store.

- [ ] **Step 3: Define section and destination models**

```swift
enum SettingsDestination: Hashable {
    case dashboard, profiles, keyboardSetup, theme, packs, height
    case customKeyboard, qwerty, typingBehavior, snippets, privacy
    case featureGuide, pro, feedback, rate, kioskProvisioning
}

struct HomeSection: Equatable {
    enum ID: String { case dashboard, keyboard, typingBehavior, content, account, help }
    let id: ID
    let rows: [SettingsDestination]
}
```

`HomeSettingsModel.sections` must be deterministic and contain no commerce rows in Typing & Behavior.

- [ ] **Step 4: Build `TypingBehaviorViewController`**

Render one switch per `BehaviorSetting`, plus iCloud Sync in a separate section. Reuse the existing icons and copy. On change, call the enum setter and reload only the affected row.

- [ ] **Step 5: Convert Home to sections and remove behavior toggles from Store**

Keep purchases, restore, feature flags, and debug rows in Store. Preserve all existing navigation destinations and analytics source strings.

- [ ] **Step 6: Run focused tests and manually smoke phone navigation**

Verify every row opens its existing destination and Store contains no operational toggles.

- [ ] **Step 7: Commit**

```bash
git add NumPad/Libraries/Settings NumPad/Controllers/TypingBehaviorViewController.swift \
  NumPad/Controllers/HomeViewController.swift NumPad/Controllers/StoreViewController.swift \
  NumPadTests/BehaviorSettingTests.swift NumPadTests/HomeSettingsModelTests.swift \
  NumPad.xcodeproj/project.pbxproj
git commit -m "refactor: organize settings outside the store"
```

---

### Task 3: Add the typed Profile schema and layout preferences

**Files:**
- Create: `NumPad/Libraries/KeyboardLayoutPreferences.swift`
- Create: `NumPad/Libraries/Profiles/KeyboardProfile.swift`
- Modify: `NumPad/Libraries/SharedExtensions.swift`
- Test: `NumPadTests/KeyboardProfileTests.swift`

**Interfaces:**
- Produces: `QwertyLayoutMode: String, Codable, CaseIterable`
- Produces: `NumpadPlacement: String, Codable, CaseIterable`
- Produces: `KeyboardProfile`, `KeyboardProfile.Configuration`, `KeyboardProfile.KioskPolicy`

- [ ] **Step 1: Write schema round-trip and validation tests**

Test a complete profile, a kiosk timeout below 30 seconds, a future schema version, and malformed enum raw values.

```swift
func test_profileRoundTripsWithoutPersonalContent() throws {
    let profile = KeyboardProfile.testFixture
    let decoded = try JSONDecoder().decode(
        KeyboardProfile.self,
        from: JSONEncoder().encode(profile))
    XCTAssertEqual(decoded, profile)
}
```

- [ ] **Step 2: Add shared layout enums**

```swift
enum QwertyLayoutMode: String, Codable, CaseIterable {
    case automatic, centered, split, compactLeft, compactRight
}

enum NumpadPlacement: String, Codable, CaseIterable {
    case automatic, center, left, right, fullWidth
}
```

Add app-group keys and typed `UserPrefs` properties with `.automatic` defaults.

- [ ] **Step 3: Implement the complete schema**

Implement these exact nested value types; initializers may provide defaults, but persisted property names and meanings must remain stable:

```swift
extension KeyboardProfile {
    struct Configuration: Codable, Equatable {
        var keyboardTypeRaw: String
        var themeRaw: String
        var automaticDarkMode: Bool
        var heightRaw: String
        var reversedMode: Bool
        var roundedCorners: Bool
        var grid: Bool
        var customKeyboardConfig: CustomKeyboardConfig?
        var handednessRaw: String
        var hapticsEnabled: Bool
        var soundEnabled: Bool
        var repurposeNextKey: Bool
        var clipboardHistoryEnabled: Bool
        var inlineCalculator: Bool
        var liveMathPreview: Bool
        var cursorControls: Bool
        var smartPackDefaulting: Bool
        var resultTapeEnabled: Bool
        var keyboardPageRaw: String
        var qwertyPrimaryPackRaw: String?
        var packDisplayBehaviorRaw: String
        var qwertyPeriodComma: Bool
        var qwertyAutocorrect: Bool
        var qwertySuggestions: Bool
        var qwertyDoubleSpacePeriod: Bool
        var qwertyLayoutModeRaw: String
        var numpadPlacementRaw: String
    }

    struct KioskPolicy: Codable, Equatable {
        var inactivityTimeout: TimeInterval
        var resetPageAndPack: Bool
        var dismissOverlays: Bool
        var clearResultTape: Bool
        var clearClipboardHistory: Bool
        var requireAdministratorAuthentication: Bool
    }
}
```

Store enum raw values but validate them through exhaustive `validated()` methods before persistence or application. Accept `keyboardPageRaw` only as `"numpad"` or `"qwerty"`. `KioskPolicy.validated()` clamps nothing silently; it returns a descriptive validation error for timeouts outside 30–3,600 seconds.

- [ ] **Step 4: Prove excluded data cannot enter the schema**

The type must have no properties for snippets, clipboard contents, tape contents, learned words, touch offsets, purchases, or entitlement state. Add a test that exported JSON contains none of the corresponding app-group key names.

- [ ] **Step 5: Run tests in both app and Keyboard compilation contexts**

Build both schemes/targets so `KeyboardLayoutPreferences.swift` target membership is verified.

- [ ] **Step 6: Commit**

```bash
git add NumPad/Libraries/KeyboardLayoutPreferences.swift NumPad/Libraries/Profiles \
  NumPad/Libraries/SharedExtensions.swift NumPadTests/KeyboardProfileTests.swift \
  NumPad.xcodeproj/project.pbxproj
git commit -m "feat: add versioned keyboard profiles"
```

---

### Task 4: Persist, apply, and migrate Profiles

**Files:**
- Create: `NumPad/Libraries/Profiles/KeyboardProfileStore.swift`
- Create: `NumPad/Libraries/Profiles/KeyboardProfileFactory.swift`
- Create: `NumPad/Libraries/Profiles/KeyboardProfileApplier.swift`
- Create: `NumPad/Libraries/Profiles/KeyboardProfileMigration.swift`
- Modify: `NumPad/Libraries/SharedExtensions.swift`
- Modify: `NumPad/AppDelegate.swift`
- Test: `NumPadTests/KeyboardProfileStoreTests.swift`
- Test: `NumPadTests/KeyboardProfileApplierTests.swift`
- Test: `NumPadTests/KeyboardProfileMigrationTests.swift`

**Interfaces:**
- Produces: `KeyboardProfileStore.load() -> ProfileStoreSnapshot`
- Produces: `KeyboardProfileStore.save(_:) throws`
- Produces: `KeyboardProfileApplier.apply(_:entitlements:) throws -> ApplyResult`
- Produces: `KeyboardProfileMigration.runIfNeeded()`

- [ ] **Step 1: Test persistence, corruption, ID collisions, and idempotent migration**

Use unique throwaway `UserDefaults(suiteName:)` instances. Assert corrupt data returns built-ins plus a diagnostic without overwriting the original bytes.

- [ ] **Step 2: Implement built-in factories**

Create Standard, Calculator, Finance, Inventory, Writing, Accessibility, and Kiosk templates. Kiosk uses the exact defaults in the design. Built-ins use fixed UUIDs so repeated launches do not duplicate them.

- [ ] **Step 3: Implement transactional application**

```swift
struct ApplyResult: Equatable {
    let changedKeys: Set<String>
    let fallbacks: [ProfileFallback]
}

struct ProfileEntitlements {
    let pro: Bool
    let kioskHeight: Bool
    let financePack: Bool
}
```

Validate first, compute every resulting value, then write. Call the injected notifier once only after all writes succeed. Never mutate the saved profile to reflect a fallback.

- [ ] **Step 4: Implement first-run migration**

Snapshot current preferences as “My Current Setup,” persist built-ins plus the snapshot, mark the snapshot active, and write a migration-version key. Re-running must produce byte-equivalent profile state.

- [ ] **Step 5: Integrate migration before settings UI is constructed**

Run from app launch after Firebase/default initialization but before `HomeViewController` reads profile state.

- [ ] **Step 6: Add profile keys to CloudSync**

Sync the profile blob and active ID only after migration has completed. Retain last-writer-wins behavior and never sync clipboard/personalization content.

- [ ] **Step 7: Run all profile tests and full suite**

- [ ] **Step 8: Commit**

```bash
git add NumPad/Libraries/Profiles NumPad/Libraries/SharedExtensions.swift \
  NumPad/AppDelegate.swift NumPadTests/KeyboardProfileStoreTests.swift \
  NumPadTests/KeyboardProfileApplierTests.swift \
  NumPadTests/KeyboardProfileMigrationTests.swift NumPad.xcodeproj/project.pbxproj
git commit -m "feat: persist apply and migrate keyboard profiles"
```

---

### Task 5: Add Profile management UI and dashboard integration

**Files:**
- Create: `NumPad/Controllers/ProfilesViewController.swift`
- Create: `NumPad/Controllers/ProfileEditorViewController.swift`
- Modify: `NumPad/Controllers/HomeViewController.swift`
- Modify: `NumPad/Views/KeyboardPreviewView.swift`
- Test: `NumPadUITests/ProfileAndKioskTests.swift`

**Interfaces:**
- Consumes: `KeyboardProfileStore`, `KeyboardProfileFactory`, `KeyboardProfileApplier`
- Produces: a Profiles destination reusable from phone and iPad.

- [ ] **Step 1: Write UI tests for built-in visibility and activation**

Use a debug launch argument/defaults reset so the test begins deterministically. Assert built-ins are visible, activating Finance changes the checkmark, and duplicate creates an editable custom profile.

- [ ] **Step 2: Build the profiles list**

Sections: Active, Built-in Templates, My Profiles. Built-ins can activate or duplicate but not rename/delete. Custom profiles can activate, duplicate, rename, edit, or delete after confirmation. Prevent deletion of the active profile.

- [ ] **Step 3: Build the editor**

Use grouped UIKit rows for profile name, pack, appearance, height/layout, QWERTY behavior, feedback, and optional kiosk policy. Save only after full validation; cancellation does not apply partial values.

- [ ] **Step 4: Add the active-profile dashboard row and preview**

The home dashboard displays active name, fallback warning if any, and a compact `KeyboardPreviewView`. Profile activation refreshes the preview and table without relaunching.

- [ ] **Step 5: Run UI tests on iPhone**

- [ ] **Step 6: Commit**

```bash
git add NumPad/Controllers/ProfilesViewController.swift \
  NumPad/Controllers/ProfileEditorViewController.swift \
  NumPad/Controllers/HomeViewController.swift NumPad/Views/KeyboardPreviewView.swift \
  NumPadUITests/ProfileAndKioskTests.swift NumPad.xcodeproj/project.pbxproj
git commit -m "feat: add profile management"
```

---

### Task 6: Add QWERTY preferences and feedback parity

**Files:**
- Modify: `NumPad/Libraries/SharedExtensions.swift`
- Modify: `NumPad/Controllers/QwertySetupViewController.swift`
- Modify: `Keyboard/Libraries/QwertyPageHost.swift`
- Modify: `Keyboard/Views/QwertyKeyboardView.swift`
- Modify: `Keyboard/KeyboardViewController.swift`
- Test: `NumPadTests/QwertyPreferencesTests.swift`

**Interfaces:**
- Produces: `UserPrefs.qwertyAutocorrect`, `qwertySuggestions`, `qwertyDoubleSpacePeriod`
- Changes `QwertyPageHost.init` to accept `keyTouchDownFeedback: () -> Void`.

- [ ] **Step 1: Write default and persistence tests**

Assert all three new preferences default true and are stored in an isolated app-group-compatible defaults wrapper.

- [ ] **Step 2: Add constants and typed preferences**

```swift
case qwertyAutocorrectEnabled, qwertySuggestionsEnabled, qwertyDoubleSpacePeriodEnabled
```

All default true. Each UI mutation posts settings sync.

- [ ] **Step 3: Add setup switches**

Add Autocorrect, Suggestions, and Double-Space Period to a Typing section. Retain Period & Comma in Layout.

- [ ] **Step 4: Honor preferences in the host**

- Skip `applyPendingCorrection` when autocorrect is off.
- Keep literal insertion unchanged.
- Render stable empty suggestion slots when suggestions are off.
- Pass `UserPrefs.qwertyDoubleSpacePeriod` to `DoubleSpacePeriod.decision`.

- [ ] **Step 5: Forward touch-down feedback**

Add a QWERTY view delegate callback for key touch-down. Pass a closure from `KeyboardViewController` that calls the same `playClick()` path as numpad touch-down. Ensure a long press triggers feedback once, not on every repeat tick.

- [ ] **Step 6: Test Full Access off/on manually**

Core key insertion must work in both states. Haptic/sound behavior must match the existing documented Full Access policy and global toggles.

- [ ] **Step 7: Commit**

```bash
git add NumPad/Libraries/SharedExtensions.swift \
  NumPad/Controllers/QwertySetupViewController.swift \
  Keyboard/Libraries/QwertyPageHost.swift Keyboard/Views/QwertyKeyboardView.swift \
  Keyboard/KeyboardViewController.swift NumPadTests/QwertyPreferencesTests.swift
git commit -m "feat: add qwerty preferences and input feedback"
```

---

### Task 7: Make QWERTY height preset-aware

**Files:**
- Modify: `Keyboard/KeyboardViewController.swift:304-349`
- Modify: `Keyboard/Libraries/QwertyPageHost.swift:114-124`
- Modify: `NumPadTests/NumPadTests.swift`
- Modify: `NumPadUITests/E2EMatrixTests.swift`

**Interfaces:**
- Produces: `KeyboardHeightPreset.resolvedHeight(stored:kioskEntitled:idiom:compactHeight:containerHeight:) -> CGFloat`, the single resolver for both pages.

- [ ] **Step 1: Add pure resolver tests**

Assert Small < Regular < Tall < Kiosk on iPad, unentitled Kiosk equals Tall, the 50% cap applies, and floating iPad returns no custom constraint.

- [ ] **Step 2: Move height math into the shared resolver**

```swift
static func resolvedHeight(
    stored: KeyboardHeightPreset,
    kioskEntitled: Bool,
    idiom: UIUserInterfaceIdiom,
    compactHeight: Bool,
    containerHeight: CGFloat
) -> CGFloat
```

Use this function for both numpad and QWERTY. Remove QWERTY’s 344/384 fixed-height source.

- [ ] **Step 3: Preserve suggestion-bar minimum geometry**

At Small, verify the remaining four key rows retain at least 44 points each. If the shared preset falls below that invariant after clamping, raise only the QWERTY minimum and cover it with a test.

- [ ] **Step 4: Extend E2E height checks**

Switch pages under every preset and assert page switching does not reset the selection or collapse to minimum.

- [ ] **Step 5: Commit**

```bash
git add Keyboard/KeyboardViewController.swift Keyboard/Libraries/QwertyPageHost.swift \
  NumPad/Libraries/Keyboard.swift NumPadTests/NumPadTests.swift \
  NumPadUITests/E2EMatrixTests.swift
git commit -m "fix: apply height presets to qwerty"
```

---

### Task 8: Introduce measured autocorrect confidence

**Files:**
- Create: `NumPad/Libraries/Qwerty/QwertyCorrectionConfidence.swift`
- Modify: `NumPad/Libraries/Qwerty/QwertyAutocorrect.swift`
- Modify: `Keyboard/Libraries/QwertyPageHost.swift`
- Modify: `NumPadTests/QwertyAutocorrectTests.swift`
- Create: `NumPadTests/QwertyCorrectionConfidenceTests.swift`
- Modify: `NumPadTests/QwertyEvalHarnessTests.swift`
- Modify: `docs/plans/full-keyboard/research/2026-07-21-eval-baseline.md`

**Interfaces:**
- Produces: `QwertyCorrectionConfidence.Features`
- Produces: `QwertyCorrectionConfidence.Decision`
- Changes `QwertyAutocorrect.decide` to require an explicit auto-apply decision.

- [ ] **Step 1: Add precision/coverage metrics before changing production**

Extend the existing corpus harness to report candidate top-1/top-3, auto-apply precision, coverage, and p95 for a policy. Pin the current behavior as a baseline row.

- [ ] **Step 2: Write policy tests**

Cover exact keep, acronym, number-containing word, user-rejected word, personal word, edit-distance-one high-frequency candidate, ambiguous equal candidates, long edit distance, and unknown candidate.

- [ ] **Step 3: Implement candidate features**

```swift
struct Features: Equatable {
    let typedLength: Int
    let editDistance: Int
    let firstCheckerIndex: Int
    let candidateFrequencyRank: Int?
    let runnerUpFrequencyRank: Int?
    let isPersonalCandidate: Bool
}

enum Decision: Equatable {
    case suggestOnly
    case autoApply
}
```

Use the existing restricted Damerau-Levenshtein implementation extracted into a small shared helper rather than duplicating test-only code.

- [ ] **Step 4: Run a predeclared threshold sweep**

Evaluate a small grid over maximum edit distance, word-length floor, maximum rank, and runner-up margin. Select the simplest policy satisfying all design gates: ≥95% precision, ≥35% coverage, ≥91.7% top-3, <16 ms p95.

- [ ] **Step 5: Apply the mechanical result**

If a policy passes, wire it and record exact numbers. If none passes, keep suggestions but make autocorrect default off and record that gate outcome. Do not change gate thresholds after seeing results.

- [ ] **Step 6: Run all QWERTY tests and update the evaluation record**

- [ ] **Step 7: Commit**

```bash
git add NumPad/Libraries/Qwerty/QwertyCorrectionConfidence.swift \
  NumPad/Libraries/Qwerty/QwertyAutocorrect.swift Keyboard/Libraries/QwertyPageHost.swift \
  NumPadTests/QwertyAutocorrectTests.swift NumPadTests/QwertyCorrectionConfidenceTests.swift \
  NumPadTests/QwertyEvalHarnessTests.swift \
  docs/plans/full-keyboard/research/2026-07-21-eval-baseline.md \
  NumPad.xcodeproj/project.pbxproj
git commit -m "feat: gate qwerty autocorrect by measured confidence"
```

---

### Task 9: Stabilize suggestion UI and correction feedback

**Files:**
- Modify: `Keyboard/Views/QwertySuggestionBarView.swift`
- Modify: `Keyboard/Libraries/QwertyPageHost.swift`
- Modify: `NumPad/Libraries/Qwerty/QwertyAutocorrect.swift`
- Modify: `NumPadTests/QwertyAutocorrectTests.swift`
- Modify: `NumPadUITests/QwertyRealisticTypingTests.swift`

**Interfaces:**
- Produces: `QwertySuggestionBarView.State` with exactly three slots.

- [ ] **Step 1: Write state tests**

```swift
XCTAssertEqual(State.empty.slots.count, 3)
XCTAssertEqual(State.typing(literal: "teh", candidates: ["the"]).slots.count, 3)
XCTAssertEqual(State.corrected(original: "teh", replacement: "the").slots.count, 3)
```

- [ ] **Step 2: Replace variable button creation with three persistent buttons**

Empty slots are disabled and visually blank. Accessibility hides empty slots. Slot frames remain stable across state changes.

- [ ] **Step 3: Add corrected state**

Visually mark the applied candidate, place the original literal in the undo slot, and give it the accessibility hint “Revert correction.” Tapping it performs the same reversal as immediate backspace.

- [ ] **Step 4: Preserve no-next-word behavior**

At a boundary show `State.empty`; do not connect the rejected bigram predictor.

- [ ] **Step 5: Run realistic typing UI test**

Verify chip taps, correction feedback, literal undo, autocap, page switch, and pack switch. If simulator activation fails, capture the failure attachment and run the same script on a physical device before release.

- [ ] **Step 6: Commit**

```bash
git add Keyboard/Views/QwertySuggestionBarView.swift \
  Keyboard/Libraries/QwertyPageHost.swift \
  NumPad/Libraries/Qwerty/QwertyAutocorrect.swift \
  NumPadTests/QwertyAutocorrectTests.swift NumPadUITests/QwertyRealisticTypingTests.swift
git commit -m "feat: stabilize qwerty suggestions and correction undo"
```

---

### Task 10: Add long-press alternates and safe punctuation rules

**Files:**
- Create: `NumPad/Libraries/Qwerty/QwertyAlternates.swift`
- Create: `NumPad/Libraries/Qwerty/QwertyPunctuationRules.swift`
- Create: `Keyboard/Views/QwertyAlternateMenuView.swift`
- Modify: `Keyboard/Views/QwertyKeyboardView.swift`
- Modify: `Keyboard/Libraries/QwertyPageHost.swift`
- Test: `NumPadTests/QwertyAlternatesTests.swift`
- Test: `NumPadTests/QwertyPunctuationRulesTests.swift`

**Interfaces:**
- Produces: `QwertyAlternates.values(for:) -> [String]`
- Produces: `QwertyPunctuationRules.decision(before:inserting:) -> EditDecision`

- [ ] **Step 1: Write complete map and punctuation tests**

Pin alternates for `a, c, e, i, n, o, s, u, y, ', ", -, $, £, €`. Test contractions, opening/closing quote context, space removal before punctuation, empty/unknown context, URLs/email-like contexts, and no-op cases.

- [ ] **Step 2: Implement the static alternates catalog**

Keep it app-bundled and deterministic. No locale/network lookup.

- [ ] **Step 3: Implement pure punctuation edits**

```swift
struct EditDecision: Equatable {
    let deletions: Int
    let insertion: String
}
```

The default is zero deletions and literal insertion. Apply transformations only when the test-covered context is unambiguous.

- [ ] **Step 4: Build accessible alternate menu UI**

Long-press character keys with alternates, track the finger across choices, insert on release, cancel cleanly, and expose each alternate as an accessibility element. A long press must suppress the base tap.

- [ ] **Step 5: Integrate punctuation decision before insertion**

Preserve layer bounce, autocap, personalization buffering, and suggestion refresh.

- [ ] **Step 6: Commit**

```bash
git add NumPad/Libraries/Qwerty/QwertyAlternates.swift \
  NumPad/Libraries/Qwerty/QwertyPunctuationRules.swift \
  Keyboard/Views/QwertyAlternateMenuView.swift Keyboard/Views/QwertyKeyboardView.swift \
  Keyboard/Libraries/QwertyPageHost.swift NumPadTests/QwertyAlternatesTests.swift \
  NumPadTests/QwertyPunctuationRulesTests.swift NumPad.xcodeproj/project.pbxproj
git commit -m "feat: add qwerty alternates and smart punctuation"
```

---

### Task 11: Improve backspace repeat and space-bar cursor mode

**Files:**
- Create: `NumPad/Libraries/Qwerty/QwertyBackspacePolicy.swift`
- Create: `NumPad/Libraries/Qwerty/QwertyCursorAccumulator.swift`
- Modify: `Keyboard/Libraries/QwertyPageHost.swift`
- Modify: `Keyboard/Views/QwertyKeyboardView.swift`
- Test: `NumPadTests/QwertyBackspacePolicyTests.swift`
- Test: `NumPadTests/QwertyCursorAccumulatorTests.swift`

**Interfaces:**
- Produces: `QwertyBackspacePolicy.action(elapsed:) -> Action`
- Produces: `QwertyCursorAccumulator.consume(translation:) -> Int`

- [ ] **Step 1: Write timing and accumulator tests**

Pin: 0.35-second initial delay; 0.10-second character repeat; acceleration to 0.06 after 1.5 seconds; word-delete eligibility after 2.5 seconds only when the existing preference is enabled. Test cursor dead band, positive/negative movement, reversal, and fractional carry.

- [ ] **Step 2: Implement the pure policies**

Use injected elapsed time in tests. Do not couple policy to `Timer` or UIKit.

- [ ] **Step 3: Replace the fixed backspace timer**

Schedule the next tick using the policy’s interval. Use the existing safe word-boundary deletion helper when action is `.deleteWord`; otherwise delete one character. Refresh suggestions at a throttled cadence and on end.

- [ ] **Step 4: Require a hold before cursor mode**

A tap remains a space. On long-press, blank/activate the space-bar label, initialize the accumulator, and use pan deltas for `adjustTextPosition`. Restore appearance and refresh state on end/cancel.

- [ ] **Step 5: Verify VoiceOver and Reduce Motion**

The gesture must not remove the normal Space accessibility action and must not rely on animation for state communication.

- [ ] **Step 6: Commit**

```bash
git add NumPad/Libraries/Qwerty/QwertyBackspacePolicy.swift \
  NumPad/Libraries/Qwerty/QwertyCursorAccumulator.swift \
  Keyboard/Libraries/QwertyPageHost.swift Keyboard/Views/QwertyKeyboardView.swift \
  NumPadTests/QwertyBackspacePolicyTests.swift \
  NumPadTests/QwertyCursorAccumulatorTests.swift NumPad.xcodeproj/project.pbxproj
git commit -m "feat: improve qwerty deletion and cursor control"
```

---

### Task 12: Scope touch learning and add personal dictionary management

**Files:**
- Create: `NumPad/Libraries/Qwerty/QwertyPersonalizationContext.swift`
- Modify: `NumPad/Libraries/Qwerty/QwertyTouchPersonalization.swift`
- Modify: `NumPad/Libraries/Qwerty/QwertyPersonalDictionary.swift`
- Modify: `Keyboard/Libraries/QwertyPageHost.swift`
- Create: `NumPad/Controllers/PersonalDictionaryViewController.swift`
- Modify: `NumPad/Controllers/QwertySetupViewController.swift`
- Test: `NumPadTests/QwertyPersonalizationContextTests.swift`
- Modify: `NumPadTests/QwertyTouchPersonalizationTests.swift`
- Modify: `NumPadTests/QwertyPersonalDictionaryTests.swift`

**Interfaces:**
- Produces: `QwertyPersonalizationContext(deviceClass:layoutMode:)`
- Changes touch-offset persistence to `[QwertyPersonalizationContext: QwertyTouchPersonalization]`.

- [ ] **Step 1: Write migration and isolation tests**

Assert phone/automatic offsets do not affect iPad/split; layout modes remain isolated; legacy data migrates once to phone/automatic; corrupt data becomes empty.

- [ ] **Step 2: Add context-aware persistence**

Use a versioned envelope so future dimensions can be added. Continue normalizing offsets by key size.

- [ ] **Step 3: Add dictionary mutation APIs**

```swift
mutating func add(_ word: String) throws
mutating func remove(_ word: String)
var sortedWords: [String] { get }
```

Normalize whitespace/case, reject empty/numeric-only/over-64-character entries, and persist through the existing app-group key.

- [ ] **Step 4: Build the dictionary screen**

Show alphabetized learned words, Add, swipe-to-delete, and Reset All with confirmation. Never show touch offsets or analytics.

- [ ] **Step 5: Integrate QWERTY setup navigation and live reset generation**

- [ ] **Step 6: Commit**

```bash
git add NumPad/Libraries/Qwerty/QwertyPersonalizationContext.swift \
  NumPad/Libraries/Qwerty/QwertyTouchPersonalization.swift \
  NumPad/Libraries/Qwerty/QwertyPersonalDictionary.swift \
  Keyboard/Libraries/QwertyPageHost.swift \
  NumPad/Controllers/PersonalDictionaryViewController.swift \
  NumPad/Controllers/QwertySetupViewController.swift \
  NumPadTests/QwertyPersonalizationContextTests.swift \
  NumPadTests/QwertyTouchPersonalizationTests.swift \
  NumPadTests/QwertyPersonalDictionaryTests.swift NumPad.xcodeproj/project.pbxproj
git commit -m "feat: manage and scope qwerty personalization"
```

---

### Task 13: Build the adaptive iPad settings shell and dashboard

**Files:**
- Create: `NumPad/Controllers/DashboardViewController.swift`
- Create: `NumPad/Controllers/IPadSettingsSplitViewController.swift`
- Modify: `NumPad/SceneDelegate.swift`
- Modify: `NumPad/Controllers/Base/ViewController.swift`
- Modify: `NumPad/Controllers/HomeViewController.swift`
- Test: `NumPadUITests/IPadSettingsTests.swift`

**Interfaces:**
- Consumes: `SettingsDestination`, Profiles controllers, existing settings controllers.
- Produces: iPad sidebar/detail navigation without changing phone root behavior.

- [ ] **Step 1: Write iPad UI assertions**

Launch on `QA-iPad-Pro-13`. Assert sidebar exists, Dashboard is selected, detail content has a maximum readable width, profile/typing/kiosk destinations are reachable, and no table row spans the full display width.

- [ ] **Step 2: Build `DashboardViewController`**

Programmatic UIKit composition:

- keyboard readiness/status card;
- active profile and fallback card;
- `KeyboardPreviewView`;
- Try It field with toolbar;
- kiosk readiness summary when the Kiosk profile is active.

Move ownership of the Try It field out of the root overlay. On phone, embed the same dashboard as the first home destination.

- [ ] **Step 3: Build `IPadSettingsSplitViewController`**

Use `.doubleColumn`, sidebar list appearance, one `UINavigationController` for detail, and `preferredDisplayMode = .oneBesideSecondary`. Map every `SettingsDestination` to a concrete existing/new controller through one exhaustive factory.

- [ ] **Step 4: Select roots in `SceneDelegate`**

Use the split controller for `.pad`; preserve the storyboard initial root on phone. Deep links must route into the appropriate detail controller on both shells.

- [ ] **Step 5: Exercise size changes**

Test portrait, landscape, 50/50 Split View, narrow Slide Over, and Stage Manager-like widths. Detail content must cap at 760 points and center; the split may collapse using standard UIKit behavior.

- [ ] **Step 6: Commit**

```bash
git add NumPad/Controllers/DashboardViewController.swift \
  NumPad/Controllers/IPadSettingsSplitViewController.swift NumPad/SceneDelegate.swift \
  NumPad/Controllers/Base/ViewController.swift NumPad/Controllers/HomeViewController.swift \
  NumPadUITests/IPadSettingsTests.swift NumPad.xcodeproj/project.pbxproj
git commit -m "feat: add adaptive ipad settings dashboard"
```

---

### Task 14: Add iPad keyboard placement and QWERTY layout modes

**Files:**
- Create: `NumPad/Libraries/Qwerty/QwertyLayoutGeometry.swift`
- Modify: `NumPad/Libraries/KeyboardLayoutPreferences.swift`
- Modify: `Keyboard/Views/QwertyKeyboardView.swift`
- Modify: `Keyboard/KeyboardViewController.swift`
- Modify: `NumPad/Controllers/QwertySetupViewController.swift`
- Modify: `NumPad/Controllers/KeyboardHeightViewController.swift`
- Test: `NumPadTests/QwertyLayoutGeometryTests.swift`
- Modify: `NumPadTests/CustomKeyboardLayoutTests.swift`
- Modify: `NumPadUITests/E2EMatrixTests.swift`

**Interfaces:**
- Produces: `QwertyLayoutGeometry.frames(bounds:rows:mode:idiom:)`
- Produces: `NumpadGeometry.contentFrame(bounds:placement:idiom:)`

- [ ] **Step 1: Write geometry tests for every mode**

Assert frames are finite, nonnegative, nonoverlapping within a row, inside bounds, and preserve minimum 44×44 targets. Assert centered mode is capped/centered, split has a thumb gap, compact modes pin correctly, and phone automatic reproduces current full-width geometry.

- [ ] **Step 2: Move manual QWERTY frame calculation into the pure resolver**

`QwertyKeyboardView.layoutSubviews` becomes an adapter that asks the resolver for frames and assigns them. Keep touch-offset denormalization after frames change.

- [ ] **Step 3: Add a constrained numpad content container**

On regular-width iPad, automatic/center uses a tested maximum width; left/right pins that container; fullWidth preserves legacy. On phone, narrow multitasking, and floating iPad, automatic preserves legacy.

- [ ] **Step 4: Add iPad-only settings rows and profile application**

QWERTY Layout and NumPad Placement appear only where useful. Changes persist, post settings sync, and re-layout a visible keyboard.

- [ ] **Step 5: Run screenshot and hit-target tests**

Capture iPad portrait/landscape for centered, split, compact, and kiosk numpad. Verify touch routing uses the new frames and suggestion-bar hit testing remains intact.

- [ ] **Step 6: Commit**

```bash
git add NumPad/Libraries/Qwerty/QwertyLayoutGeometry.swift \
  NumPad/Libraries/KeyboardLayoutPreferences.swift \
  Keyboard/Views/QwertyKeyboardView.swift Keyboard/KeyboardViewController.swift \
  NumPad/Controllers/QwertySetupViewController.swift \
  NumPad/Controllers/KeyboardHeightViewController.swift \
  NumPadTests/QwertyLayoutGeometryTests.swift \
  NumPadTests/CustomKeyboardLayoutTests.swift NumPadUITests/E2EMatrixTests.swift \
  NumPad.xcodeproj/project.pbxproj
git commit -m "feat: adapt keyboard layouts for ipad"
```

---

### Task 15: Add kiosk readiness, session reset, and administrator guard

**Files:**
- Create: `NumPad/Libraries/Kiosk/KioskReadiness.swift`
- Create: `NumPad/Libraries/Kiosk/KioskSessionPolicy.swift`
- Create: `NumPad/Controllers/KioskProvisioningViewController.swift`
- Modify: `Keyboard/KeyboardViewController.swift`
- Modify: `NumPad/Controllers/ProfileEditorViewController.swift`
- Modify: `NumPad/Controllers/IPadSettingsSplitViewController.swift`
- Test: `NumPadTests/KioskReadinessTests.swift`
- Test: `NumPadTests/KioskSessionPolicyTests.swift`
- Modify: `NumPadUITests/ProfileAndKioskTests.swift`

**Interfaces:**
- Produces: `KioskReadiness.evaluate(_:) -> ReadinessReport`
- Produces: `KioskSessionPolicy.actions(lastInteraction:now:) -> Set<ResetAction>`

- [ ] **Step 1: Write readiness truth-table tests**

Blocked: keyboard disabled or profile cannot apply. Warning: Full Access/manual confirmation mismatch, unentitled Kiosk fallback, Try It unconfirmed, Guided Access warning unacknowledged. Ready: every required/acknowledged item is satisfied.

- [ ] **Step 2: Write deterministic timeout tests**

Inject dates. Assert no reset before timeout and exact actions after timeout. Clamp is validation failure, not silent mutation.

- [ ] **Step 3: Build the provisioning checklist**

Each row shows pass/warning/block, explanation, and action. “Open Settings” uses the existing Settings route. Try It confirmation is recorded only after the app receives at least one input event in its field.

- [ ] **Step 4: Add administrator authentication**

Use `LAContext.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)` before entering profile editing when the active Kiosk policy requires it. Handle unavailable authentication with a blocking explanation; never create or store a custom PIN.

- [ ] **Step 5: Enforce session reset in the extension**

Persist last interaction coarsely. On next interaction/appearance after timeout:

- dismiss overlays;
- return to configured page/pack;
- clear result tape if selected;
- clear clipboard history if selected.

Do not delete snippets or profile configuration.

- [ ] **Step 6: Run kiosk UI test and physical Guided Access checklist**

- [ ] **Step 7: Commit**

```bash
git add NumPad/Libraries/Kiosk NumPad/Controllers/KioskProvisioningViewController.swift \
  NumPad/Controllers/ProfileEditorViewController.swift \
  NumPad/Controllers/IPadSettingsSplitViewController.swift \
  Keyboard/KeyboardViewController.swift NumPadTests/KioskReadinessTests.swift \
  NumPadTests/KioskSessionPolicyTests.swift NumPadUITests/ProfileAndKioskTests.swift \
  NumPad.xcodeproj/project.pbxproj
git commit -m "feat: add kiosk provisioning and session policy"
```

---

### Task 16: Add safe profile documents and Managed App Configuration

**Files:**
- Create: `NumPad/Libraries/Profiles/KeyboardProfileDocument.swift`
- Create: `NumPad/Libraries/Profiles/ManagedProfileConfiguration.swift`
- Create: `NumPad/Controllers/ProfileImportCoordinator.swift`
- Modify: `NumPad/Controllers/ProfilesViewController.swift`
- Modify: `NumPad/AppDelegate.swift`
- Test: `NumPadTests/KeyboardProfileDocumentTests.swift`
- Test: `NumPadTests/ManagedProfileConfigurationTests.swift`

**Interfaces:**
- Produces: `KeyboardProfileDocument.decodeAndValidate(_:) throws -> KeyboardProfile`
- Produces: `ManagedProfileConfiguration.parse(_:) -> Result<ManagedProfileRequest, ManagedProfileError>`

- [ ] **Step 1: Write hostile-input tests**

Test future schema, invalid enum, 10,000 custom keys, 10,000-character name/key, invalid token, timeout outside range, duplicate UUID, embedded entitlement/purchase keys, malformed JSON, and valid round trip.

- [ ] **Step 2: Implement `.numpadprofile` document envelope**

```swift
struct KeyboardProfileDocument: Codable {
    static let currentEnvelopeVersion = 1
    let envelopeVersion: Int
    let exportedAt: Date
    let profile: KeyboardProfile
}
```

Cap document size at 256 KB, profile name at 80 characters, custom key token at 64 characters, and each custom section at its existing UI maximum.

- [ ] **Step 3: Add export/import UI**

Export through `UIActivityViewController`; import through `UIDocumentPickerViewController`. Validate before showing a confirmation summary. Assign a new UUID on collision. Imported profiles never auto-activate.

- [ ] **Step 4: Parse managed configuration**

Read `UserDefaults.standard.dictionary(forKey: "com.apple.configuration.managed")`. Support either `builtin_profile_kind` or `profile_json`, plus `lock_profile_editing`. Invalid configuration leaves local state unchanged and appears in Kiosk Provisioning diagnostics.

- [ ] **Step 5: Apply managed configuration at launch idempotently**

Record a digest of the validated managed request so unchanged configuration is not re-applied every foreground. The digest is of configuration metadata, never typed/personal content.

- [ ] **Step 6: Commit**

```bash
git add NumPad/Libraries/Profiles/KeyboardProfileDocument.swift \
  NumPad/Libraries/Profiles/ManagedProfileConfiguration.swift \
  NumPad/Controllers/ProfileImportCoordinator.swift \
  NumPad/Controllers/ProfilesViewController.swift NumPad/AppDelegate.swift \
  NumPadTests/KeyboardProfileDocumentTests.swift \
  NumPadTests/ManagedProfileConfigurationTests.swift NumPad.xcodeproj/project.pbxproj
git commit -m "feat: import export and manage profiles"
```

---

### Task 17: Add privacy-safe quality counters, accessibility, localization, and docs

**Files:**
- Create: `NumPad/Libraries/TypingQualityCounters.swift`
- Modify: `Keyboard/Libraries/QwertyPageHost.swift`
- Modify: `Keyboard/KeyboardViewController.swift`
- Modify: `NumPad/AppDelegate.swift`
- Modify: `NumPad/Libraries/SharedExtensions.swift`
- Modify: `NumPad/en.lproj/Localizable.strings`
- Modify: all existing `NumPad/*.lproj/Localizable.strings`
- Modify: `docs/PrivacyPolicy.md`
- Modify: `docs/PrivacyPolicy`
- Modify: `docs/kiosk/NumPad-for-Kiosks.md`
- Test: `NumPadTests/TypingQualityCountersTests.swift`

**Interfaces:**
- Produces: `TypingQualityCounters.increment(_:)`
- Produces: `TypingQualityCounters.drain() -> [String: Int]`

- [ ] **Step 1: Write counter privacy and drain tests**

The event enum has only the approved counter cases. Storage encodes integers only. Drain is atomic, returns stable analytics keys, and clears successfully flushed counters.

- [ ] **Step 2: Instrument only approved events**

Count key taps, suggestion shows/accepts, corrections, immediate reverts, backspace taps/repeat sessions, page switches, and short abandoned sessions. Do not pass strings from the text proxy into the counter API.

- [ ] **Step 3: Flush from the app**

On foreground, drain and log one aggregate event through `Analytics`. If logging is unavailable, retain counters for the next launch.

- [ ] **Step 4: Run accessibility audit**

Add labels/hints/traits for profile controls, three suggestion slots, alternates, layout modes, kiosk readiness, and dashboard. Verify Dynamic Type at accessibility sizes, Reduce Motion, VoiceOver order, button targets ≥44 points, and sufficient contrast.

- [ ] **Step 5: Complete localization**

Use the repository’s existing localization workflow. No new UI may display raw enum values or English-only literals outside `NSLocalizedString`. Verify Arabic/Hebrew layout does not truncate even though QWERTY correction remains US English.

- [ ] **Step 6: Update privacy and kiosk documentation**

Document aggregate counters and explicitly state what is never collected. Change the Kiosk height text from “upcoming” to current. Document Profiles, manual keyboard enablement, Full Access, Managed App Configuration limits, Guided Access software-keyboard toggle, and session clearing.

- [ ] **Step 7: Commit**

```bash
git add NumPad/Libraries/TypingQualityCounters.swift Keyboard/Libraries/QwertyPageHost.swift \
  Keyboard/KeyboardViewController.swift NumPad/AppDelegate.swift \
  NumPad/Libraries/SharedExtensions.swift NumPad/*.lproj/Localizable.strings \
  docs/PrivacyPolicy.md docs/PrivacyPolicy docs/kiosk/NumPad-for-Kiosks.md \
  NumPadTests/TypingQualityCountersTests.swift NumPad.xcodeproj/project.pbxproj
git commit -m "feat: finish privacy accessibility and localization"
```

---

### Task 18: Perform release verification and prepare the Codex review handoff

**Files:**
- Create: `docs/release/2026-07-23-usability-qwerty-ipad-kiosk-handoff.md`
- Modify only if verification finds defects: relevant source/test files, each in a separate fix commit.

**Interfaces:**
- Produces: a review-ready branch and evidence package.
- Does not produce: an archive, upload, TestFlight build, App Store submission, or release-state mutation.

- [ ] **Step 1: Confirm repository hygiene**

```bash
git status --short
git diff --check
git log --oneline --decorate --max-count=30
git diff --stat HEAD~18..HEAD
```

Expected: only intentional work; `Auto-Company/` remains untracked and untouched; no whitespace errors.

- [ ] **Step 2: Run the full unit suite**

```bash
xcodebuild test -workspace NumPad.xcworkspace -scheme NumPad \
  -destination 'platform=iOS Simulator,name=DevVault iPhone 17' \
  -derivedDataPath /Volumes/DevVault/Xcode/DerivedData/NumPad-Grok \
  -only-testing:NumPadTests CODE_SIGNING_ALLOWED=NO
```

Expected: zero failures and no unexplained new skips.

- [ ] **Step 3: Run selected UI suites on phone and iPad**

```bash
xcodebuild test -workspace NumPad.xcworkspace -scheme NumPad \
  -destination 'platform=iOS Simulator,name=DevVault iPhone 17' \
  -derivedDataPath /Volumes/DevVault/Xcode/DerivedData/NumPad-Grok \
  -only-testing:NumPadUITests/SmokeTests \
  -only-testing:NumPadUITests/ProfileAndKioskTests \
  -only-testing:NumPadUITests/QwertyRealisticTypingTests

xcodebuild test -workspace NumPad.xcworkspace -scheme NumPad \
  -destination 'platform=iOS Simulator,name=QA-iPad-Pro-13' \
  -derivedDataPath /Volumes/DevVault/Xcode/DerivedData/NumPad-Grok \
  -only-testing:NumPadUITests/IPadSettingsTests \
  -only-testing:NumPadUITests/ProfileAndKioskTests
```

Record simulator keyboard-activation failures separately from NumPad assertion failures.

- [ ] **Step 4: Build both release targets without submission**

Build the app and keyboard extension for a generic iOS device with code-signing disabled where possible. Do not archive.

- [ ] **Step 5: Execute the physical-device matrix**

Use the exact matrix in the design specification. Capture model/OS, Full Access state, profile/layout, memory observation, typing duration, correction/revert counts, and pass/fail. A missing physical-device result is an open release blocker, not “assumed pass.”

- [ ] **Step 6: Capture screenshots**

Capture current iPhone home/dashboard, iPad portrait/landscape dashboard, Profiles, Kiosk Provisioning, QWERTY centered/split, and Kiosk numpad. Store them outside the git repository or in an explicitly approved release-evidence directory.

- [ ] **Step 7: Write the handoff**

The handoff must contain:

- branch and commit list;
- diff stat;
- implemented requirements mapped to tasks;
- deviations and their reasons;
- unit/UI/device test commands and results;
- `.xcresult` paths;
- correction-confidence gate numbers;
- privacy audit result;
- screenshots paths;
- compiler warnings;
- known issues and release blockers;
- explicit statement: “No Apple archive, upload, TestFlight distribution, or App Store submission was performed.”

- [ ] **Step 8: Stop and request Codex review**

Do not fix review findings preemptively after handing off unless the owner asks. Do not perform Apple submission work.

- [ ] **Step 9: Commit only the handoff**

```bash
git add docs/release/2026-07-23-usability-qwerty-ipad-kiosk-handoff.md
git commit -m "docs: prepare usability release review handoff"
```

## Codex Review Gate

After Grok reports completion, the owner should return to Codex with the branch name and handoff path. Codex will independently:

1. Fetch and confirm the exact branch/commits.
2. Inspect the complete diff and compare it with the design and every task above.
3. Review profile migration, validation, entitlement fallback, and managed-config handling.
4. Review extension memory/lifecycle behavior, QWERTY correctness, and privacy boundaries.
5. Re-run proportionate tests and inspect `.xcresult` evidence.
6. Exercise current iPhone/iPad UI and compare screenshots.
7. Classify findings by release severity.
8. Require fixes and re-review as needed.
9. Give an explicit ready/not-ready recommendation.

Only the owner can authorize subsequent archive, upload, TestFlight, or App Store submission work.
