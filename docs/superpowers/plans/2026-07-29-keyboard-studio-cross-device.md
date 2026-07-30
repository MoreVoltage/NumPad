# Keyboard Studio Cross-Device Implementation Plan

> **For agentic implementation:** Execute with `superpowers:subagent-driven-development`. Use
> test-driven development for every behavior change, preserve one atomic commit per task, and run
> the task review gate before starting the next task.

**Goal:** Replace the confusing list/dashboard container app with the approved three-destination
Keyboard Studio experience on iPhone and an adaptive canvas/inspector plus permanently bottom-
anchored keyboard workspace on iPad, while preserving all keyboard, purchase, profile, and safety
behavior.

**Architecture:** Keep UIKit MVC and the existing lifecycle coordinator. Introduce reusable,
model-driven Studio presentation components; route iPhone through a tab shell and iPad through an
adaptive split workspace that consumes the same models and destination controllers. Keep all
settings, entitlement, profile, import, and kiosk policy logic in existing shared sources of truth.

**Tech Stack:** Swift, UIKit, XCTest/XCUITest, StoreKit 2, UserDefaults app group, Darwin
notifications, CocoaPods, Xcode workspace.

---

## Global Constraints

- Work only in `/Users/jamespikover/NumPad-studio` on `codex/keyboard-studio-ux`.
- Use `NumPad.xcworkspace`, deployment target iOS 16.0, and explicit simulator IDs.
- Do not edit or clean `/Users/jamespikover/NumPad`; it contains unrelated user work.
- New behavior follows RED → GREEN → REFACTOR. Record the failing and passing commands.
- Agents do not hand-edit `NumPad.xcodeproj/project.pbxproj`; deterministic registration with
  `ruby scripts/add_sources.rb` is allowed within the owning task and its resulting diff must be
  reviewed.
- All keyboard-affecting preferences use `UserDefaults.group` and call `SettingsSync.post()`.
- Reuse `Monetization`, `StoreManager`, `KeyboardProfileApplier`, `KioskReadiness`,
  `ManagedProfileCoordinator`, and Remote Config gates. Do not duplicate their policy.
- Kiosk height and Kiosk mode are Pro-only. Never mutate Kiosk state before entitlement.
- QWERTY remains remotely kill-switchable; autocorrect remains off by default.
- No Glide implementation or promises.
- Never log typed, clipboard, snippet, dictionary, touch-offset, or imported setup content.
- User-facing copy avoids pack, profile, provisioning, MDM, kill switch, remote config,
  entitlement, and app-group jargon.
- Dynamic Type, VoiceOver, RTL, Reduce Motion, Bold Text, increased contrast, 44-point targets,
  portrait, landscape, and multitasking are required.
- Do not archive, upload, or submit to Apple.

### Binding references

- Design: `docs/superpowers/specs/2026-07-29-keyboard-studio-cross-device-design.md`
- Code audit and API contract: `docs/plans/2026-07-27-keyboard-studio-contract.md`
- Approved iPhone storyboard:
  `/tmp/numpad-ux-concepts/.superpowers/brainstorm/8532-1785175219/content/keyboard-studio-full-storyboard-restored.html`
- Approved iPad storyboard:
  `/tmp/numpad-ux-concepts/.superpowers/brainstorm/8532-1785175219/content/keyboard-studio-ipad-storyboard.html`

## Task 1: Stabilize and test the Studio design system

**Files:**

- Review/modify: `NumPad/Libraries/DesignSystem/*.swift`
- Add: `NumPadTests/StudioDesignSystemTests.swift`
- Modify centrally after implementation: `NumPad.xcodeproj/project.pbxproj`

- [ ] Add behavior tests for palette contrast roles, Dynamic Type/scaled typography, control
  accessibility state, non-color-only selection, and 44-point minimum control sizing. Each test
  must name the production break it catches and fail for the missing/broken behavior.
- [ ] Review the inherited uncommitted design-system sources for iOS 16 compatibility, Auto Layout
  correctness, shadow clipping, trait changes, RTL, and unnecessary `public` API.
- [ ] Make the smallest corrections required for the tests and approved visual language.
- [ ] Register the test and any corrected sources centrally.
- [ ] Run the focused test file, build the NumPad simulator target, self-review the diff, and commit:
  `feat: add adaptive Keyboard Studio design system`.

## Task 2: Build the truthful model-driven keyboard preview

**Files:**

- Replace: `NumPad/Views/KeyboardPreviewView.swift`
- Add: `NumPad/Views/StudioKeyboardPreviewView.swift`
- Add: `NumPad/Libraries/StudioKeyboardPreviewModel.swift`
- Add: `NumPadTests/StudioKeyboardPreviewTests.swift`
- Update call sites: `NumPad/Controllers/ThemeViewController.swift`,
  `NumPad/Controllers/DashboardViewController.swift`, `NumPad/Views/OnboardingKeyboardMockView.swift`

- [ ] Write failing tests proving the current model snapshots theme, pack, effective height, number
  order, grid, rounded corners, and Letters availability without mutating settings.
- [ ] Write failing tests proving projected setup previews use `KeyboardProfileApplier.probe`,
  including locked-pack/theme/Kiosk fallbacks, and leave shared defaults unchanged.
- [ ] Implement the `StudioKeyboardPreviewModel` and `StudioKeyboardPreviewView` API documented in
  the contract. Obtain key captions from real layout data; do not use a literal fake 4×4 array.
- [ ] Make height alter aspect ratio, reverse digit rows visually, preserve glass effects, and make
  grid/corners visibly truthful.
- [ ] Expose the preview as one VoiceOver image with a localized summary and no per-key focus.
- [ ] Migrate existing call sites through a compatibility wrapper if needed.
- [ ] Run focused tests and a simulator build, self-review, and commit:
  `feat: render truthful live keyboard previews`.

## Task 3: Introduce shared Studio navigation and the iPhone three-tab shell

**Files:**

- Add: `NumPad/Controllers/Studio/StudioTabBarController.swift`
- Add: `NumPad/Controllers/Studio/StudioNavigationFactory.swift`
- Add: `NumPad/Controllers/Studio/KeyboardStudioViewController.swift`
- Add: `NumPad/Controllers/Studio/FeaturesStudioViewController.swift`
- Add: `NumPad/Controllers/Studio/HelpStudioViewController.swift`
- Modify: `NumPad/Controllers/Base/ViewController.swift`
- Modify: `NumPad/Libraries/DeepLinkRouter.swift` only if tests prove a compatibility gap
- Add/modify: `NumPadTests/StudioNavigationTests.swift`, `NumPadTests/DeepLinkRouterTests.swift`

- [ ] Write failing tests proving the phone shell contains exactly Keyboard, Features, and Help;
  Keyboard is selected by default; each tab is navigation-wrapped; Dashboard is absent; and the
  gear presents Advanced.
- [ ] Write failing compatibility tests for store, feature-guide, profile-document, and DEBUG deep
  links from a tab shell. Do not change routing code if the existing recursion already passes.
- [ ] Replace only the phone branch of `ViewController.installContentShell()` with the new tab
  shell. Preserve splash, onboarding, pending deep-link draining, and lifecycle behavior.
- [ ] Add skeleton destination controllers using Studio components and stable accessibility IDs.
  Every visible button must do something; do not add placeholder/no-op dashboard actions.
- [ ] Add `studio_opened` and `advanced_opened` analytics without logging user content.
- [ ] Run focused tests plus launch smoke tests, self-review, and commit:
  `feat: replace phone settings list with Keyboard Studio tabs`.

## Task 4: Complete Keyboard Studio and focused quick-change screens

**Files:**

- Expand: `NumPad/Controllers/Studio/KeyboardStudioViewController.swift`
- Add: `NumPad/Controllers/Studio/AppearanceStudioViewController.swift`
- Add: `NumPad/Controllers/Studio/KeySetStudioViewController.swift`
- Add: `NumPad/Controllers/Studio/SizeAndFeelStudioViewController.swift`
- Add: `NumPad/Controllers/Studio/LettersStudioViewController.swift`
- Add: `NumPad/Libraries/Studio/StudioKeySetCatalog.swift`
- Add: `NumPad/Libraries/Studio/StudioSettingsWriter.swift`
- Add: `NumPadTests/StudioKeySetCatalogTests.swift`,
  `NumPadTests/StudioSettingsWriterTests.swift`
- Add/modify: `NumPadUITests/KeyboardStudioUITests.swift`

- [ ] Write failing tests for the seven user-facing key sets, including one Calculations tile for
  `.math`/`.math2`, a Date & time tile, no duplicate Math, and correct pack lock states.
- [ ] Write failing tests that every mutation writes shared defaults and posts one settings sync;
  a locked choice presents Pro and performs no write.
- [ ] Build the Keyboard first viewport: honest readiness hero, truthful preview, Try It field,
  quick-change actions, and conditional Letters action.
- [ ] Implement Appearance, Choose keys, and Size & feel using focused tiles/rows. Keep current
  settings behavior and immediate preview refresh.
- [ ] Surface Letters only when `FeatureFlags.isQwertyPageAvailable`; retain QWERTY kill-switch
  fallback and default-off autocorrect.
- [ ] Add source-specific `quick_change_opened` and `key_set_selected` analytics.
- [ ] Add phone UI tests for ready/needs-attention, locked/free, Dynamic Type, and a quick-change
  round trip. Run focused unit/UI tests, self-review, and commit:
  `feat: complete the phone Keyboard Studio`.

## Task 5: Complete Features, Help, and simplified Advanced

**Files:**

- Expand: `NumPad/Controllers/Studio/FeaturesStudioViewController.swift`
- Expand: `NumPad/Controllers/Studio/HelpStudioViewController.swift`
- Add: `NumPad/Controllers/Studio/AdvancedStudioViewController.swift`
- Add: `NumPad/Controllers/Studio/SavedSetupsStudioViewController.swift`
- Add: `NumPad/Controllers/Studio/SavedSetupDetailViewController.swift`
- Add: `NumPad/Controllers/Studio/MoveSetupsViewController.swift`
- Adapt: `NumPad/Controllers/KioskProvisioningViewController.swift`
- Reuse/adapt: existing Snippets, Custom Keyboard, Privacy, Instructions, Store, and support flows
- Add: `NumPad/Libraries/Studio/StudioSavedSetupPresentation.swift`
- Add: `NumPadTests/StudioSavedSetupPresentationTests.swift`
- Add/modify: `NumPadUITests/StudioDestinationsUITests.swift`

- [ ] Write failing tests for plain-language saved-setup names/descriptions, conditional Writing
  visibility, managed-settings visibility, and read-only projected change summaries.
- [ ] Build Features around Calculator tools, Reusable text, and Custom keys. Preserve Full Access
  explanations and Pro gating; do not claim Full Access detection.
- [ ] Build Help around setup status, practical use guides, privacy, feedback, rating, restore,
  version, and policy. Every row must have a working destination/action.
- [ ] Build Advanced with Saved setups, Kiosk mode, Move setups, and conditional Managed settings.
  Replace corporate terminology in the visible UI while preserving underlying validation,
  authentication, rollback, import/export, and managed editing locks.
- [ ] Saved setup detail must show a truthful projected preview and explicit changes using `probe`;
  apply remains transactional.
- [ ] Adapt Kiosk UI to “Kiosk mode,” retain honest Guided Access limitations, and make the entire
  activation path Pro-only.
- [ ] Add relevant analytics and UI coverage. Run focused tests, self-review, and commit:
  `feat: simplify Features Help and Advanced`.

## Task 6: Build the adaptive iPad Studio workspace and permanent keyboard dock

**Files:**

- Replace/adapt: `NumPad/Controllers/IPadSettingsSplitViewController.swift`
- Replace/adapt: `NumPad/Controllers/DashboardViewController.swift`
- Add: `NumPad/Controllers/Studio/IPadStudioWorkspaceViewController.swift`
- Add: `NumPad/Views/StudioKeyboardDockView.swift`
- Add: `NumPad/Libraries/Studio/IPadStudioLayout.swift`
- Modify: `NumPad/Controllers/Base/ViewController.swift`
- Add/modify: `NumPadTests/IPadSettingsTests.swift`,
  `NumPadTests/IPadLaunchOrchestrationTests.swift`
- Add/modify: `NumPadUITests/IPadStudioUITests.swift`,
  `NumPadUITests/ScreenshotCaptureTests.swift`

- [ ] Write failing pure layout tests for regular-width landscape, portrait, half/third split view,
  safe-area changes, and compact fallback. Assert the keyboard dock remains outside the scroll
  container and pinned to the bottom layout guide.
- [ ] Write failing tests for Automatic/Left/Center/Right placement, centered default, utility rail
  visibility, and safe fallback when explicit placement no longer fits.
- [ ] Replace the old iPad dashboard/settings split with the shared Keyboard/Features/Help model.
  Use canvas plus inspector above the dock at regular landscape widths and one scrollable control
  column above the dock in portrait/narrow widths.
- [ ] Implement `StudioKeyboardDockView` with a truthful preview and content insets that keep the
  last upper control reachable. The dock must not scroll, float, or disappear during destination
  updates.
- [ ] Refresh for rotations, multitasking resize, settings sync, purchase/restore, content-size,
  and trait changes without duplicate observers or stale constraints.
- [ ] Preserve old iPad deep links and accessibility IDs where compatibility tests require them,
  while removing Dashboard and corporate labels from visible navigation.
- [ ] Add signed iPad UI tests and screenshot states for landscape, portrait, narrow split,
  Keyboard/Features/Help/Advanced, and each dock height. Run focused tests, self-review, and commit:
  `feat: add adaptive iPad Studio with anchored keyboard dock`.

## Task 7: Add first-install iPad height choice and enforce Kiosk Pro

**Files:**

- Add: `NumPad/Controllers/OnboardingHeightViewController.swift`
- Modify: `NumPad/Controllers/OnboardingViewController.swift`
- Modify: `NumPad/Libraries/OnboardingStep.swift`
- Modify: `NumPad/Libraries/OnboardingFlow.swift` if a pure decision seam is required
- Modify: `NumPad/Controllers/KeyboardHeightViewController.swift`
- Modify: `NumPad/Controllers/KioskProvisioningViewController.swift`
- Modify: `NumPad/Libraries/Monetization+KioskHeight.swift` only if one shared Kiosk-mode helper is
  needed
- Add/modify: `NumPadTests/OnboardingFlowTests.swift`,
  `NumPadTests/KioskReadinessTests.swift`, `NumPadTests/KeyboardProfileApplierTests.swift`
- Add/modify: `NumPadUITests/IPadStudioUITests.swift`

- [ ] Write failing tests proving the height step appears only for first-install iPad onboarding,
  skip preserves the default, and existing users are not interrupted.
- [ ] Write failing tests proving unentitled Kiosk height and Kiosk-mode activation perform no
  shared-default mutation; Pro/grandfathered users retain access; purchase/restore unlocks without
  restart; profile fallback remains Tall.
- [ ] Add the visual Compact/Regular/Tall/Kiosk choice to iPad onboarding after enablement and
  before Try It. Samples may float because the screen explicitly labels them as visual choices.
- [ ] Persist free choices and post settings sync. Locked Kiosk opens the StoreKit-backed Pro sheet
  with a localized price when available.
- [ ] Consolidate Kiosk-mode gating on an existing or new shared monetization helper so every
  activation entry point has the same rule.
- [ ] Add onboarding analytics for height viewed/selected/skipped without content data.
- [ ] Run focused unit/UI tests, self-review, and commit:
  `feat: add iPad height onboarding and Pro-gated Kiosk mode`.

## Task 8: Localize, harden accessibility, and remove obsolete visible paths

**Files:**

- Modify: all `NumPad/*.lproj/Localizable.strings` and keyboard tables only where new extension
  copy is actually added
- Modify: Studio controllers/views from Tasks 1–7
- Modify/delete references: `NumPad/Libraries/Settings/HomeSettingsModel.swift`,
  `NumPad/Controllers/HomeViewController.swift`, legacy Dashboard/iPad navigation paths
- Modify: UI tests and screenshot test manifests
- Add: `docs/release/2026-07-29-keyboard-studio-evidence.md`

- [ ] Add English source strings and complete parseable entries for every supported app locale.
  Reuse existing translations where exact meaning matches; mark new machine-translated copy for
  native review in evidence rather than silently claiming linguistic approval.
- [ ] Audit every screen with VoiceOver identifiers/labels/traits/hints, accessibility Dynamic
  Type sizes, RTL, Bold Text, Reduce Motion, increased contrast, and 44-point targets.
- [ ] Remove the old visible list/dashboard navigation while retaining compatibility code only
  where routes/tests still require it. No visible button or row may be a no-op.
- [ ] Validate analytics names and ensure no sensitive content can enter attributes.
- [ ] Update UI screenshots/fixtures so Keyboard is visibly bottom-anchored on iPad.
- [ ] Parse all localization/plist/privacy files, run lints and focused UI accessibility tests,
  self-review, and commit:
  `chore: localize and harden Keyboard Studio`.

## Task 9: Full verification, remediation, and release handoff

**Files:**

- Update: `docs/release/2026-07-29-keyboard-studio-evidence.md`
- Modify production/tests only for verified defects found in this task

- [ ] Run `git diff --check` and inventory branch scope from merge base `0f584a2c`.
- [ ] Run the full unit suite and record exact pass/fail/skip counts.
- [ ] Run signed iPhone UI matrices on compact, standard, and large simulators.
- [ ] Run signed iPad UI matrices in portrait, landscape, and supported multitasking widths.
- [ ] Run generic-device Release builds for NumPad and Keyboard.
- [ ] Parse all `.strings`, plists, entitlements, and privacy manifests; confirm privacy policy
  copies match.
- [ ] Reconfirm autocorrect defaults are false, QWERTY gate-off fallback is safe, Kiosk height/mode
  are Pro-only, no Glide promise/code was added, and no Apple submission action occurred.
- [ ] For every defect, first add a failing regression test, then fix and rerun focused/full gates.
- [ ] Record physical-device and native-translation review items honestly.
- [ ] Self-review all changes from `0f584a2c`, then commit final evidence:
  `docs: record Keyboard Studio verification evidence`.
