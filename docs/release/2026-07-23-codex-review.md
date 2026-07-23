# Codex Review — Usability, QWERTY, iPad, and Kiosk

**Reviewed branch:** `grok/usability-qwerty-ipad-kiosk`  
**Reviewed commit:** `bb24b82c`  
**Baseline:** `d9606559`  
**Verdict:** **CHANGES REQUIRED — NOT READY FOR APPLE REVIEW**

## Executive assessment

The branch compiles and its unit-test foundation is substantial, but it is not a complete implementation of the approved plan. The implementation handoff itself identifies Tasks 7–8 and 10–17 as partial and Task 9 as not done. Live iPad review also exposed regressions and incomplete navigation that unit tests do not cover.

Do not submit this build to Apple and do not treat the remaining work as polish. Correctness defects affect iPad launch/lifecycle behavior, profile application, paid-pack entitlements, QWERTY height, kiosk readiness, and iPad presentation.

## Verification performed

- Full unit suite: **711 tests passed, 2 skipped, 0 failures**.
  - Result: `/Volumes/DevVault/Xcode/DerivedData/NumPad-CodexReview/Logs/Test/Test-NumPad-2026.07.23_10-06-44--0700.xcresult`
- Targeted iPad UI test: **failed** because two visible `Profiles` labels make the query ambiguous.
  - Test: `ProfileAndKioskTests.test_profilesBuiltInsVisibleAndDuplicateCreatesCustom()`
  - Result: `/Volumes/DevVault/Xcode/DerivedData/NumPad-CodexReview/Logs/Test/Test-NumPad-2026.07.23_10-10-45--0700.xcresult`
- Live iPad Pro 13-inch simulator review:
  - Split view launches.
  - The detail dashboard contains only three table rows and leaves most of the screen unused.
  - No live keyboard preview, Try It field, readiness summary, entitlement-fallback card, or kiosk-focused surface is present.
  - Several sidebar destinations visibly navigate to a new Dashboard instance instead of performing their advertised action.
  - Screenshot: `/Users/jamespikover/.codex/visualizations/2026/07/23/019f8d55-02d0-7292-b644-1e7a52ddc104/grok-review-ipad-home-2.png`
- `Auto-Company/` remains untracked and untouched.

## Release-blocking findings

### 1. iPad bypasses the app's launch, foreground, and deep-link coordinator

`SceneDelegate` installs `IPadSettingsSplitViewController` directly on iPad, while iPhone receives the storyboard root (`NumPad/SceneDelegate.swift:14-22`). The skipped `ViewController` owns:

- onboarding/instructions and first-run flows;
- `StoreManager.start()` and foreground entitlement refresh;
- `CloudSync.start()`, pull, and push;
- analytics counter flushing;
- Remote Config-derived first-run defaults;
- pending URL consumption and Store/debug deep-link routing.

`SceneDelegate.handleDeepLink` only stores the URL in `AppDelegate.pendingURL` (`NumPad/SceneDelegate.swift:36-40`). There is no iPad consumer, so `numpad://store-preview` can remain pending instead of opening the store.

**Required correction:** introduce one shared app lifecycle/deep-link coordinator used by both iPhone and iPad roots, or retain the existing root coordinator while embedding the iPad split UI. Add cold-launch, foreground, and URL-routing tests for iPad.

### 2. QWERTY height can collapse to the 220-point floor

`QwertyPageHost.baseHeight` treats `containerView.bounds.height` as the available container height (`Keyboard/Libraries/QwertyPageHost.swift:124-133`). After layout, that is the current keyboard height, not the host screen/window height. Applying the 50% ceiling to a roughly 344-point keyboard produces a ceiling below the 220-point minimum, so the resolver returns 220.

The numpad path already documents and avoids this exact regression by using `KeyboardHeightPreset.clampCeilingContainerHeight` with a trustworthy window/screen height (`Keyboard/KeyboardViewController.swift:328-349`).

**Required correction:** make both pages use one height-resolution path fed by the host window/screen and actual size-class state. Add page-switch, rotation, settings-sync, floating-keyboard, and all-preset regression tests.

### 3. Every built-in profile inherits a test fixture

`KeyboardProfile.Configuration.defaults` returns `.testFixture` (`NumPad/Libraries/Profiles/KeyboardProfileFactory.swift:155-158`). That fixture selects the Math pack, rounded corners, autocorrect enabled, and other test-oriented values (`NumPad/Libraries/Profiles/KeyboardProfile.swift:168-198`).

Consequently, Standard and every built-in derived from `defaults` can unexpectedly apply test settings. This is production data corruption by construction.

The same duplicated-default problem affects migration snapshots: `snapshotCurrent` falls back to `grid = false` and `qwertyAutocorrect = true`, while the live production defaults are grid-on and autocorrect-off. A migrated “My Current Setup” can therefore disagree with the settings it claims to preserve.

**Required correction:** define explicit production defaults from the actual typed app defaults and have snapshots read those accessors rather than duplicating literals. Keep fixtures in the test target or name them so production cannot call them. Add exact-value tests for every built-in and an unset-default migration test.

### 4. Profile application does not model real entitlements

`ProfileEntitlements` represents only Pro, Kiosk Height, and Finance (`KeyboardProfileApplier.swift:8-12`). `MonetizationGating.isPackLocked` then treats every other selectable à-la-carte pack as Pro-only (`KeyboardProfileApplier.swift:126-139`).

Users who purchased Symbols, Programmer, Units, or another individual pack can have a valid profile silently downgraded to Default.

**Required correction:** use the shared `Monetization.isLocked(pack:)` source of truth or pass a complete immutable entitlement snapshot. Cover every pack and each purchase combination.

### 5. Profiles are not deterministic or transactional

- When `customKeyboardConfig` is `nil`, the applier never clears an existing custom layout (`KeyboardProfileApplier.swift:107-115`).
- Editing the active profile saves the model but does not reapply it (`NumPad/Controllers/ProfilesViewController.swift:201-213`).
- Duplicate, delete, and edit persistence errors are swallowed with `try?`.
- Active-profile identity is written separately from the profile snapshot, which permits partial state if persistence fails.
- Activation applies settings and posts the Darwin notification before the profile snapshot is saved. If that later save fails, the keyboard has changed even though the UI reports an apply failure.
- CloudSync pull copies the remote profile blob and active ID but does not apply that profile's individual settings. The displayed active profile can therefore disagree with the live keyboard.

**Required correction:** define and test an atomic apply/save contract. Prevalidate the complete desired snapshot, clear omitted state, reapply active edits and remotely selected profiles, report persistence failures, and notify only after all persistence succeeds (or implement rollback). Test custom-to-standard, locked-fallback, failed-save, and cloud-pull transitions.

### 6. Profile migration can permanently mark a failed migration complete

`KeyboardProfileMigration.runIfNeeded` ignores `store.save` failure and then unconditionally writes the migration version (`NumPad/Libraries/Profiles/KeyboardProfileMigration.swift:25-32`).

**Required correction:** stamp the version only after a successful validated save. Preserve diagnostics and allow a later retry. Add a malformed-legacy-setting test.

### 7. Profiles action sheet is unsafe on iPad

`ProfilesViewController` presents a `.actionSheet` without configuring `popoverPresentationController.sourceView/sourceRect` or a bar-button anchor (`NumPad/Controllers/ProfilesViewController.swift:122-151`). UIKit requires an anchor on iPad.

**Required correction:** anchor to the selected profile cell or replace the sheet with an iPad-appropriate context menu. Add an iPad UI test that reaches and operates every action.

### 8. The iPad interface is a shell, not the planned larger-form-factor experience

`DashboardViewController` contains three rows only (`NumPad/Controllers/DashboardViewController.swift:9-34`). It lacks the planned preview, Try It input, readiness, fallback explanations, and kiosk-focused controls.

`IPadSettingsSplitViewController` maps Send Feedback, Rate, 7-8-9 on Top, Rounded, and Grid to `DashboardViewController` (`NumPad/Controllers/IPadSettingsSplitViewController.swift:18-38`), so those rows do not do what their labels promise.

The live layout is an elongated phone settings list beside a mostly blank detail pane. There is no readable-width treatment or deliberate use of the large screen.

**Required correction:** implement the approved iPad dashboard and responsive two-column design. Actions must remain actions and toggles must be real toggles. Support 11/13-inch portrait/landscape, Split View, Stage Manager, and Dynamic Type.

### 9. Kiosk readiness can report success without establishing readiness

`profileApplies` is hard-coded `true` (`NumPad/Controllers/KioskProvisioningViewController.swift:25-36`). “Confirm Try It” sets a Boolean when its row is tapped rather than observing successful keyboard input (`KioskProvisioningViewController.swift:70-89`). Full Access is likewise self-attested.

The LocalAuthentication check protects only one navigation route to Profiles (`KioskProvisioningViewController.swift:92-115`); Profiles remains accessible elsewhere. The kiosk inactivity policy is not enforced by the Keyboard extension.

The kiosk policy source is not even a member of the Keyboard extension target, and it has no production call sites. Timeout/reset, overlay dismissal, result-tape clearing, and clipboard-history clearing therefore never occur, allowing prior-session clipboard data to remain available to the next kiosk operator.

**Required correction:** compute readiness from the active applied profile and its actual fallback result; confirm Try It through a real text-input event; centralize the admin edit guard; add the shared policy types to the extension target; wire and test inactivity reset/dismiss/clear behavior in the extension. Do not claim that MDM can grant Full Access or Guided Access settings it cannot control.

### 10. QWERTY confidence claims are not supported by runtime data

The host always supplies `checkerIndex: 0` and `nil` frequency ranks (`Keyboard/Libraries/QwertyPageHost.swift:343-357`). The confidence policy auto-applies edit-distance-one candidates when ranks are absent (`NumPad/Libraries/Qwerty/QwertyCorrectionConfidence.swift:18-31`). Therefore the advertised rank and margin gates are not actually enforced.

The required corpus sweep was not run, and autocorrect is default-off. That default is appropriate, but the user can still enable an unvalidated implementation.

**Required correction:** compute real candidate/runners-up features, run and retain the specified corpus evidence, and keep automatic correction disabled or unavailable until all accuracy and latency gates pass.

### 11. Imported custom layouts are insufficiently validated

`KeyboardProfileDocument` caps the envelope at 256 KB and searches raw JSON for a short forbidden-key list (`NumPad/Libraries/Profiles/KeyboardProfileDocument.swift:30-45`). `KeyboardProfile.Configuration.validated()` does not structurally validate `customKeyboardConfig` row/column counts, key lengths, supported actions, or rendering limits (`NumPad/Libraries/Profiles/KeyboardProfile.swift:111-144`).

**Required correction:** validate the decoded model structurally against the same bounds as the editor/extension before persistence. Add oversized-array, oversized-token, unsupported-action, schema, and fuzz-style malformed-input tests.

### 12. Much of the approved typing and kiosk scope is dead code or absent

The handoff accurately records the following:

- Task 9 is not done.
- Alternates/punctuation, backspace/cursor, personalization, geometry, kiosk session enforcement, imports, counters, accessibility, localization, privacy documentation, and physical-device verification remain partial.
- Several new policy/geometry types are unit-tested but not wired into the production keyboard.

Pure modules do not satisfy an end-to-end feature task. Wire them into the runtime with UI and integration coverage, or remove/defer them explicitly instead of counting them as implementation.

## Additional required cleanup

- Complete the profile editor: height, custom layout, handedness, behavior, page/top-strip, layout mode/placement, kiosk policy, and entitlement-aware choices are absent.
- Require confirmation before deleting a profile and leave the UI/store unchanged when deletion fails.
- Localize built-in names, status descriptions, and all new user-facing strings; do not display `String(describing:)` enum values.
- Integrate managed configuration and profile import/export through a deliberate coordinator and user-visible validation failures.
- Instrument and flush privacy-safe typing counters only as documented. Make shared read-modify-write and drain operations concurrency-safe, and do not remove counters before successful delivery.
- Fix iPad UI tests to target a stable accessibility identifier rather than an ambiguous label.
- Remove conditional assertions that allow the duplicate-profile UI test to pass without ever finding or exercising Duplicate.
- Replace the handoff's stale reviewed SHA and finish the evidence log, which currently ends after Task 4.

## Acceptance gate for the next Codex review

The next handoff should not say “done” until all of the following are true:

1. Every approved task is either end-to-end complete or explicitly removed from the release scope with owner approval.
2. Full unit tests pass from a clean DerivedData directory.
3. All relevant UI suites pass on at least one iPhone and both 11-inch and 13-inch iPad simulator configurations.
4. iPad cold launch, foreground entitlement refresh, CloudSync lifecycle, onboarding, and `numpad://store-preview` routing are verified.
5. Every built-in profile has exact-value tests; active edit, custom-to-standard, corrupted migration, and every paid-pack entitlement transition are covered.
6. QWERTY height remains stable across page changes, presets, rotation, settings sync, floating keyboard, and multitasking.
7. Autocorrect stays unavailable/default-off until measured accuracy, coverage, top-three, and p95 latency gates pass with retained results.
8. Kiosk readiness is evidence-based and inactivity/reset behavior passes end-to-end.
9. VoiceOver, Dynamic Type, Reduce Motion, localization, and privacy documentation sweeps are complete.
10. The physical-device matrix and five-minute typing sessions are recorded without assumed passes.
11. No Apple archive, upload, TestFlight distribution, or App Store submission occurs; return the final branch to Codex for review first.
