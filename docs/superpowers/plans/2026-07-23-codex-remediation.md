# NumPad Codex Remediation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Resolve every implementable P1 blocker and associated P2 correctness gap from the 2026-07-23 Codex Round-2 review, then produce honest release evidence without changing Apple release state.

**Architecture:** Preserve the UIKit/MVC and app-group architecture. Make profile and cloud changes transactional at the persistence boundary, centralize kiosk session state in a shared pure policy, keep QWERTY interaction state in testable value types with thin UIKit adapters, and connect the existing iPad geometry/personalization models to production views. Complete profile document and managed-configuration flows through small app-only coordinators.

**Tech Stack:** Swift 5, UIKit, XCTest/XCUITest, iOS 15+, CocoaPods through `NumPad.xcworkspace`.

## Global Constraints

- Work only on `codex/remediate-qwerty-ipad-kiosk`; do not alter the original Grok checkout.
- Use only GPT-5.6-sol with high reasoning for implementation and review agents. Do not delegate to Opus, Claude, or any unapproved model.
- Open and test `NumPad.xcworkspace`, never the `.xcodeproj`.
- Preserve iOS 15.0 compatibility and the existing two-target UIKit/MVC architecture.
- Do not add a dependency, SDK, backend, target, prediction engine, or glide implementation.
- Keep autocorrect default-OFF until the production-path confidence gate passes its stated thresholds.
- Profile writes, Cloud Sync pulls, and active-profile edits must be all-or-nothing and post `SettingsSync` at most once after success.
- Kiosk readiness is true only for an active `.kiosk` profile with a valid active policy and successfully resolved applied configuration.
- Kiosk timeout must restore the active profile's configured pack/page, clear only policy-selected data, and count all meaningful keyboard interactions.
- Do not archive, upload, distribute through TestFlight, submit to App Store Connect, or change Apple release state.
- Never mark simulator, accessibility, localization, privacy, warning, screenshot, or physical-device gates complete without current evidence.

---

### Task 1: Make Profiles, Migration, Documents, and Cloud Sync Transactional

**Files:**
- Modify: `NumPad/Libraries/Profiles/KeyboardProfileFactory.swift`
- Modify: `NumPad/Libraries/Profiles/KeyboardProfileStore.swift`
- Modify: `NumPad/Libraries/Profiles/KeyboardProfileApplier.swift`
- Modify: `NumPad/Libraries/Profiles/KeyboardProfileMigration.swift`
- Modify: `NumPad/Libraries/Profiles/KeyboardProfileDocument.swift`
- Modify: `NumPad/Libraries/Profiles/CloudSync+Profiles.swift`
- Modify: `NumPad/Libraries/SharedExtensions.swift`
- Modify: `NumPad/Controllers/ProfilesViewController.swift`
- Modify: `NumPad/Controllers/ProfileEditorViewController.swift`
- Modify: `NumPadTests/KeyboardProfileApplierTests.swift`
- Modify: `NumPadTests/KeyboardProfileMigrationTests.swift`
- Modify: `NumPadTests/KeyboardProfileDocumentTests.swift`
- Create: `NumPadTests/CloudSyncProfilesTests.swift`

**Interfaces:**
- Produce: one typed `KeyboardProfile.Configuration.productionDefaults` used by factory defaults and clean migration fallback.
- Produce: `KeyboardProfileStore.replaceAndApply(_:previous:applier:entitlements:) throws -> ApplyResult`, which restores both the profile snapshot and live settings on failure.
- Change: profile editor save completion to `(KeyboardProfile) -> Result<Void, Error>`; pop only for `.success`.
- Change: `CloudSync.afterPull` to receive a complete `[String: Any?]` pre-pull snapshot and return success/failure.
- Produce: separate constants for corrupt profile bytes and migration diagnostics.

- [ ] **Step 1: Write failing profile-default and active-edit transaction tests**

Add assertions that every clean `snapshotCurrent` field equals the corresponding typed live accessor, including `grid == true`. Add a test where active-profile application throws after an edited profile is proposed and assert both the stored profile and every live key remain unchanged.

- [ ] **Step 2: Run the focused tests and verify RED**

Run:

```bash
xcodebuild test -workspace NumPad.xcworkspace -scheme NumPad \
  -destination 'platform=iOS Simulator,id=3A037648-417A-4B4B-8180-D06539B28FF3' \
  -derivedDataPath /Volumes/DevVault/Xcode/DerivedData/NumPad-CodexRemediation \
  -only-testing:NumPadTests/KeyboardProfileApplierTests \
  CODE_SIGNING_ALLOWED=NO
```

Expected: failures for the grid mismatch and non-atomic edit behavior.

- [ ] **Step 3: Implement typed defaults and atomic active-profile replacement**

Create `productionDefaults` from the same typed defaults used by `Keyboard`, `UserPrefs`, and layout preferences. Make the store/applier transaction snapshot the complete prior profile blob, active ID, custom keyboard, and live setting keys before any mutation. Restore all of them on any validation, entitlement, encoding, persistence, or apply error. Return the error to the editor and keep the editor visible.

- [ ] **Step 4: Write failing migration, document, and Cloud Sync tests**

Cover:

- existing corrupt profile bytes are copied byte-for-byte to the corrupt-data key before migration writes;
- the diagnostic string uses a distinct key;
- export rejects structurally invalid custom layouts exactly as import does;
- Cloud Sync restores every `CloudSync.syncedKeys` value for a missing active UUID, corrupt blob, invalid custom layout, or application error;
- a successful pull commits every key and applies the selected profile once.

- [ ] **Step 5: Run the new tests and verify RED**

Run the four focused test classes. Expected: the new preservation/export/rollback assertions fail against the Round-2 implementation.

- [ ] **Step 6: Implement complete validation and rollback**

Snapshot all synced keys before mirroring. Validate the pulled profile document and active identity before committing the pull. On failure restore every key, record a non-sensitive diagnostic, do not notify, and leave the prior active keyboard settings intact. On success apply and notify exactly once.

- [ ] **Step 7: Verify GREEN and the full unit suite**

Run the four focused classes, then all `NumPadTests`. Expected: all pass; running tests must not change a tracked file.

- [ ] **Step 8: Commit**

```bash
git add NumPad Keyboard NumPadTests
git commit -m "fix: make profile state transitions transactional"
```

---

### Task 2: Correct Kiosk Readiness and Session Reset

**Files:**
- Modify: `NumPad/Libraries/Kiosk/KioskPolicy.swift`
- Modify: `NumPad/Controllers/DashboardViewController.swift`
- Modify: `NumPad/Controllers/KioskProvisioningViewController.swift`
- Modify: `Keyboard/KeyboardViewController.swift`
- Modify: keyboard overlay delegate call sites under `Keyboard/Views/`
- Modify: `NumPadTests/KioskReadinessTests.swift`
- Modify: `NumPadTests/KioskSessionPolicyTests.swift`
- Modify: `NumPadUITests/ProfileAndKioskTests.swift`

**Interfaces:**
- Produce: `KioskSessionConfiguration`, containing policy, reset page, reset pack, and active profile ID.
- Produce: `KioskSessionPolicy.activeConfiguration(defaults:) -> KioskSessionConfiguration?`.
- Produce: `KioskSessionClock`, with coarse app-group persistence, injected `now`, and `evaluateBeforeRecordingActivity`.
- Produce: one `recordKioskActivity()` entry point used by text, pack/page, cursor, overlay, calculator, clipboard, tape, and dismissal interactions.

- [ ] **Step 1: Write failing readiness and cross-appearance tests**

Assert Standard is never kiosk-ready, Kiosk is ready only when it is active and its policy/configuration probes successfully, and a persisted interaction older than the timeout resets immediately on the next appearance before the timestamp refreshes.

- [ ] **Step 2: Run focused tests and verify RED**

Expected failures: Standard currently qualifies; last interaction is memory-only; reset destination is hardcoded.

- [ ] **Step 3: Implement the shared active configuration and clock**

Decode the active profile and policy from the app-group profile store. Persist only a coarse timestamp. Evaluate expiration first, then record activity. Return the configured page and pack with policy actions.

- [ ] **Step 4: Route every meaningful interaction through one activity function**

Cover normal keys, delete, cursor movement, pack/page changes, suggestion/alternate choices, clipboard/snippet/tax/conversion/result-tape interactions, overlay presentation/dismissal, and host appearance. Invalidate the timer in `viewWillDisappear` and `deinit`.

- [ ] **Step 5: Fix dashboard/provisioning semantics**

Show kiosk readiness only for the active Kiosk profile. Render localized, human-readable policy/fallback state rather than raw enum descriptions.

- [ ] **Step 6: Verify GREEN**

Run `KioskReadinessTests`, `KioskSessionPolicyTests`, and the targeted iPad kiosk UI test. Expected: all pass.

- [ ] **Step 7: Commit**

```bash
git add NumPad Keyboard NumPadTests NumPadUITests
git commit -m "fix: enforce kiosk profile session semantics"
```

---

### Task 3: Fix QWERTY Backspace, Space Cursor, Alternates, and Dictionary Protection

**Files:**
- Modify: `Keyboard/Libraries/QwertyPageHost.swift`
- Modify: `Keyboard/Views/QwertyKeyButton.swift`
- Modify: `Keyboard/Views/QwertyKeyboardView.swift`
- Modify: `NumPad/Libraries/Qwerty/QwertyBackspacePolicy.swift`
- Modify: `NumPad/Libraries/Qwerty/QwertyCursorAccumulator.swift`
- Modify: `NumPad/Libraries/Qwerty/QwertyAlternates.swift`
- Modify: `NumPad/Libraries/Qwerty/QwertyPersonalDictionary.swift`
- Modify: `NumPadTests/QwertyBackspacePolicyTests.swift`
- Modify: `NumPadTests/QwertyCursorAccumulatorTests.swift`
- Modify: `NumPadTests/QwertyAlternatesTests.swift`
- Modify: `NumPadTests/QwertyPersonalDictionaryTests.swift`
- Modify: `NumPadUITests/QwertyRealisticTypingTests.swift`

**Interfaces:**
- Produce: `QwertyBackspaceInteractionConfiguration(wordDeleteEnabled:initialDelay:repeatInterval:)`.
- Produce: a hold-then-pan space cursor state machine with `.idle`, `.pressing`, and `.tracking` states.
- Produce: a finger-tracked alternates callout that inserts the highlighted alternate on release and respects Shift/Caps casing.
- Change: explicit dictionary addition must immediately satisfy protection checks.

- [ ] **Step 1: Write failing tests**

Cover feature-off backspace, exactly one 0.35-second initial delay, normal Space tap, quick swipe preserving Space behavior, hold-then-drag cursor movement, cancellation, uppercase alternates, release-to-insert, and immediate explicit-word protection.

- [ ] **Step 2: Verify RED**

Run the four focused unit classes. Expected: failures for forced word deletion, double delay, immediate pan activation, lowercase-only alternates, and explicit dictionary threshold.

- [ ] **Step 3: Implement minimal policies and UIKit adapters**

Use `FeatureFlags.backspaceWordDelete`; let only the policy own the 0.35-second delay. Add an accessible active cursor visual that restores on end/cancel and does not animate when Reduce Motion is enabled. Replace the action sheet with a callout attached to the pressed key; do not overload `accessibilityHint` as storage.

- [ ] **Step 4: Verify GREEN and interaction UI coverage**

Run the focused unit classes and the targeted QWERTY interaction UI test.

- [ ] **Step 5: Commit**

```bash
git add NumPad Keyboard NumPadTests NumPadUITests
git commit -m "fix: make qwerty gestures predictable and accessible"
```

---

### Task 4: Complete Correction State, Counters, and Confidence Evidence

**Files:**
- Modify: `Keyboard/Views/QwertySuggestionBarView.swift`
- Modify: `Keyboard/Libraries/QwertyPageHost.swift`
- Modify: `Keyboard/Libraries/QwertySpellChecker.swift`
- Modify: `NumPad/Libraries/Qwerty/QwertyAutocorrect.swift`
- Modify: `NumPad/Libraries/Qwerty/QwertyCorrectionConfidence.swift`
- Modify: `NumPad/Libraries/TypingQualityCounters.swift`
- Modify: `NumPad/Libraries/SharedExtensions.swift`
- Modify: `NumPadTests/QwertyAutocorrectTests.swift`
- Modify: `NumPadTests/QwertyConfidenceGateSweepTests.swift`
- Modify: `NumPadTests/TypingQualityCountersTests.swift`
- Modify: `NumPadUITests/QwertyRealisticTypingTests.swift`
- Modify: `docs/release/2026-07-23-autocorrect-confidence-gate.md`

**Interfaces:**
- Produce: `QwertySuggestionBarView.State` with stable three slots and explicit `.suggestions`, `.corrected(original:replacement:)`, and `.undoLiteral(String)` content.
- Produce: a production-path correction evaluator shared by live typing and the confidence harness.
- Change: confidence tests return structured metrics and assert thresholds; they never write the source tree.
- Produce: cross-process-safe counters using coordinated file persistence in the app-group container, with no user content.

- [ ] **Step 1: Write failing state, counter, and gate tests**

Cover corrected marker/undo-literal state transitions, ordinary backspace, correction revert, page switch, short abandoned session, non-duplicated suggestion impressions, and two independent counter writers without lost increments.

- [ ] **Step 2: Verify RED**

Run the focused classes. Expected: missing state/counters and lost cross-process updates.

- [ ] **Step 3: Implement typed bar state and complete counter call sites**

Keep three stable slots. A correction must show its visible corrected state and literal undo action. Increment each event once at its real user-action boundary. Add every key to `Constants`.

- [ ] **Step 4: Replace the confidence harness**

Measure the complete production candidate-generation, spell-check/ranking, confidence decision, and application path. Use deterministic corpus ordering and an injected clock where unit-level timing is needed. Assert the documented precision, top-three, and latency gates. Keep autocorrect default-OFF if any gate fails; do not weaken thresholds to obtain green.

- [ ] **Step 5: Verify GREEN without source mutations**

Run focused tests twice, compare `git status`, and confirm no tracked file changes. If the quality gate honestly fails, keep it as an explicit non-default release diagnostic test or fixture-driven report generator outside normal XCTest; normal tests must remain deterministic.

- [ ] **Step 6: Commit**

```bash
git add NumPad Keyboard NumPadTests NumPadUITests docs/release
git commit -m "fix: make qwerty correction evidence trustworthy"
```

---

### Task 5: Connect iPad Geometry and Context-Scoped Personalization

**Files:**
- Modify: `Keyboard/Libraries/QwertyPageHost.swift`
- Modify: `Keyboard/Views/QwertyKeyboardView.swift`
- Modify: `Keyboard/Views/StackView.swift`
- Modify: `Keyboard/KeyboardViewController.swift`
- Modify: `NumPad/Libraries/Qwerty/QwertyLayoutGeometry.swift`
- Modify: `NumPad/Libraries/Qwerty/QwertyPersonalizationContext.swift`
- Modify: `NumPad/Libraries/Qwerty/QwertyTouchPersonalization.swift`
- Modify: `NumPadTests/QwertyLayoutGeometryTests.swift`
- Modify: `NumPadTests/QwertyPersonalizationContextTests.swift`
- Modify: `NumPadTests/QwertyKeyboardViewHitTestTests.swift`
- Modify: `NumPadUITests/E2EMatrixTests.swift`
- Modify: `NumPadUITests/ScreenshotCaptureTests.swift`

**Interfaces:**
- Produce: production frames for automatic, centered, split, compact-left, compact-right, full-width numpad, and centered numpad modes.
- Produce: versioned context-keyed personalization envelope keyed by device class and resolved layout mode.
- Preserve: one-time legacy personalization migration only into phone/automatic.

- [ ] **Step 1: Write failing production integration tests**

Assert actual QWERTY/numpad hosts consume the resolver frames, custom side columns stay inside the selected content frame, touch hit-testing uses transformed frames, and phone offsets cannot affect iPad contexts.

- [ ] **Step 2: Verify RED**

Expected: helper geometry tests pass but integration/call-site assertions fail because the helpers are unused.

- [ ] **Step 3: Wire geometry into production layout**

Resolve mode from trait collection, available bounds, and user/profile preference on every layout pass. Apply content frames without changing phone automatic behavior. Handle compact/floating widths and split gaps without overlapping suggestion hit regions.

- [ ] **Step 4: Implement context-keyed personalization**

Load/store offsets under the resolved context. Migrate the legacy blob once to phone/automatic and leave new iPad contexts empty until learned.

- [ ] **Step 5: Verify GREEN**

Run geometry, personalization, and hit-test unit classes plus the iPad layout UI matrix and screenshot tests.

- [ ] **Step 6: Commit**

```bash
git add NumPad Keyboard NumPadTests NumPadUITests
git commit -m "feat: apply adaptive ipad keyboard geometry"
```

---

### Task 6: Complete Profile Import, Export, Managed Configuration, and Editing

**Files:**
- Create: `NumPad/Libraries/Profiles/ProfileImportCoordinator.swift`
- Create: `NumPad/Libraries/Profiles/ManagedProfileCoordinator.swift`
- Modify: `NumPad/Libraries/Profiles/ManagedProfileConfiguration.swift`
- Modify: `NumPad/AppDelegate.swift`
- Modify: `NumPad/Controllers/ProfilesViewController.swift`
- Modify: `NumPad/Controllers/ProfileEditorViewController.swift`
- Modify: `NumPad/Info.plist`
- Create: `NumPadTests/ProfileImportCoordinatorTests.swift`
- Create: `NumPadTests/ManagedProfileCoordinatorTests.swift`
- Modify: `NumPadTests/ManagedProfileConfigurationTests.swift`
- Modify: `NumPadTests/KeyboardProfileDocumentTests.swift`
- Modify: `NumPadUITests/ProfileAndKioskTests.swift`

**Interfaces:**
- Produce: document-picker import and activity-controller export of the validated profile envelope.
- Produce: deterministic collision handling that assigns a new UUID and a localized copied name.
- Produce: managed digest/idempotence tracking, built-in or embedded-document application, invalid-management diagnostics, and `lock_profile_editing`.
- Expand: editor rows for custom layout, handedness, behavior/clipboard, QWERTY mode, numpad placement, and complete kiosk policy.

- [ ] **Step 1: Write failing coordinator and editor-model tests**

Cover hostile/oversized/forbidden documents, duplicate UUID collision, successful export/reimport, unchanged managed digest, changed digest, invalid managed payload, entitlement fallback, and editing lock.

- [ ] **Step 2: Verify RED**

Expected: coordinators and complete workflows do not exist.

- [ ] **Step 3: Implement import/export coordinators**

Use security-scoped document access where required, validate before storage, resolve collisions without overwriting, and present localized errors. Export only validated documents and never entitlement, dictionary, personalization, clipboard, or telemetry data.

- [ ] **Step 4: Implement managed launch application**

Read `com.apple.configuration.managed` app-side at launch/foreground. Apply only after full validation, skip identical digests, preserve the last good configuration on failure, surface a non-sensitive diagnostic, and enforce editing lock across every Profiles entry route.

- [ ] **Step 5: Complete editor rows**

Use the same enums and validation as application. Save only through Task 1's transaction and keep the editor visible on failure.

- [ ] **Step 6: Verify GREEN**

Run the new coordinator classes, document/configuration classes, and targeted profile UI tests.

- [ ] **Step 7: Commit**

```bash
git add NumPad NumPadTests NumPadUITests
git commit -m "feat: complete profile provisioning workflows"
```

---

### Task 7: Finish iPad Presentation, Deep Links, Accessibility, Localization, and Test Isolation

**Files:**
- Modify: `NumPad/Controllers/DashboardViewController.swift`
- Modify: `NumPad/Controllers/IPadSettingsSplitViewController.swift`
- Modify: `NumPad/Libraries/DeepLinkRouter.swift`
- Modify: `NumPadUITests/UITestSupport.swift`
- Modify: `NumPadUITests/ProfileAndKioskTests.swift`
- Create: `NumPadTests/IPadSettingsTests.swift`
- Modify: `NumPadTests/DeepLinkRouterTests.swift`
- Modify: all affected `*.lproj/Localizable.strings`
- Modify: `docs/PrivacyPolicy.md`
- Modify: `docs/PrivacyPolicy`
- Modify: `docs/kiosk/NumPad-for-Kiosks.md`

**Interfaces:**
- Produce: a maximum readable-width iPad detail container that adapts to Split View.
- Produce: recursive navigation resolution for the actual storyboard root-navigation → lifecycle host → split-detail hierarchy.
- Produce: deterministic UI-test app-group reset and an activation test that actually activates.

- [ ] **Step 1: Write failing dashboard/deep-link/test-isolation tests**

Cover readable width, Kiosk summary visibility, localized presentation strings, cold and warm deep links through the real hierarchy, app-group reset, and actual built-in activation before duplication.

- [ ] **Step 2: Verify RED**

Expected: full-width dashboard, simplified deep-link hierarchy, and non-reset UI state fail.

- [ ] **Step 3: Implement presentation and routing**

Constrain detail content to a readable centered width while respecting narrow Split View. Traverse child/navigation/split containers recursively and route to the visible secondary controller.

- [ ] **Step 4: Complete accessibility and localization**

Add labels, hints, traits, Dynamic Type behavior, ≥44-point targets, VoiceOver order, Reduce Motion handling, and contrast-safe states for every new control. Add every new English key to all supported localization tables using the repository's established translation workflow; do not silently fall back to raw keys.

- [ ] **Step 5: Align privacy and kiosk documentation with actual behavior**

Document profile documents, managed configuration, app-group persistence, counters containing no typed content, clipboard limitations, kiosk timeout, and administrator authentication accurately.

- [ ] **Step 6: Verify GREEN**

Run `IPadSettingsTests`, `DeepLinkRouterTests`, the iPad profile/kiosk UI class, localization-key validation, and `git diff --check`.

- [ ] **Step 7: Commit**

```bash
git add NumPad NumPadTests NumPadUITests docs
git commit -m "fix: finish ipad usability and release quality"
```

---

### Task 8: Run the Complete Verification Matrix and Produce an Honest Handoff

**Files:**
- Create: `docs/release/2026-07-23-codex-remediation-handoff.md`
- Modify: `docs/release/2026-07-23-evidence-log.md`

**Interfaces:**
- Produce: exact commit range, test commands/results, simulator models/OS versions, screenshots, warnings, accessibility/localization/privacy results, known limitations, physical-device gates, and model provenance.

- [ ] **Step 1: Run a clean unit suite**

Delete only the dedicated remediation DerivedData directory, rebuild from `NumPad.xcworkspace`, and run all `NumPadTests`. Record the `.xcresult`.

- [ ] **Step 2: Run the full UI suite on phone and 13-inch iPad**

Run `NumPadUITests` on the designated phone and iPad simulators from reset app-group state. Record every failure and `.xcresult`; do not silently retry past reproducible failures.

- [ ] **Step 3: Run archive-equivalent builds and warning audit**

Build both targets for generic iOS device with signing disabled where supported. Separate first-party warnings from Pod warnings.

- [ ] **Step 4: Capture current visual evidence**

Capture phone QWERTY, iPad dashboard portrait/landscape, centered/split/compact QWERTY, full-width/centered numpad, and Kiosk provisioning/readiness.

- [ ] **Step 5: Verify repository hygiene**

Run:

```bash
git diff --check
git status --short
git log --oneline 7f77d816..HEAD
```

Tests must not mutate tracked source or release documents.

- [ ] **Step 6: Write the handoff**

State that the owner reported an attempted Opus 4.8 delegation during the prior Grok pass. State exactly that this remediation used owner-approved GPT-5.6-sol/high only. List physical keyboard/device, VoiceOver-on-device, Guided Access, third-party host, TestFlight, archive/upload, and App Store submission as blocked until actually performed.

- [ ] **Step 7: Commit**

```bash
git add docs/release
git commit -m "docs: record codex remediation evidence"
```
