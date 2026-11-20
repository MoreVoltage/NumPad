# OPUS_RESULT — key/opus-home-shell-harden

**Date:** 2026-11-20 · **Base:** `988aaf54` · **Compared against live 2.1.1:** `478430f5` · **Version unchanged:** 2.1.1 (16)

## Commits (local only, not pushed)

| SHA | What changed |
|-----|------|
| `12c215dd` | **fix (CRITICAL):** the QWERTY page gate now needs `prereleaseBuild` (DEBUG/TestFlight) as well as the RC switch and Pro. Before this, Pro and grandfathered App Store users would have received NumPad Type. Applied in `FeatureFlags.isQwertyPageAvailable`, `KeyboardProfileApplier`, and `StudioKeyboardPreviewModel`. |
| `c3c1cc48` | **fix (HIGH/MEDIUM):** Typing & Behavior (Haptics, Sound, Inline Calculator, iCloud Sync and the other behavior toggles) is always shown on Home; before, it was hidden unless the QWERTY flag was on. The phone's dead Dashboard row was removed. New tests are in this commit. |
| `983bdea4` | docs: `REVIEW_HOME_SHELL.md` (findings by severity plus recommendations) |
| (this file) | docs: `OPUS_RESULT.md` |

## Tests added

- `IPadLaunchOrchestrationTests.test_iPhoneProductionRootIsClassicHomeNotStudioTabBar`: uses the real storyboard root with no idiom override. Checks that Home is embedded, there is no tab bar or Studio workspace anywhere in the hierarchy, and the demo field is present.
- `IPadLaunchOrchestrationTests.test_noProductionCodeInstallsStudioPhoneShell`: source contract.
- `HomeViewControllerNavigationTests` (3 tests): the table mirrors the model, each of the 12 navigable rows pushes the expected VC, and the switch rows don't navigate.
- `HomeViewControllerNavigationTests.test_qwertyRowLeadsToSetupScreen` and `QwertyCalibrationEntryPointTests`: Home → NumPad Type → Calibration presents `QwertyCalibrationViewController` full-screen.
- `NoSubscriptionProductsTests` (3 tests): the catalog is exactly lifetime Pro plus packs, `Products.storekit` has no subscription groups and only NonConsumables, and no source file references a subscription.
- `HomeSettingsModelTests`: Typing & Behavior is always visible (this replaces the test that locked in the bug), the phone has no dead Dashboard row, and every live Home row is still present.
- `QwertyGatingTests.testQwertyPageNeverAvailableInAppStoreBuilds`.

## Test run

- Simulator: **"key-opus iPhone 16"** (`63A2B051-4FD6-404B-A0B4-FACBF0B38982`, iPhone 16, iOS 27.0). I created it because no iPhone 16 simulator existed. No other simulator was touched; it is still booted and can be deleted with `xcrun simctl delete 63A2B051-4FD6-404B-A0B4-FACBF0B38982`.
- Toolchain: Xcode-beta 27.0 (`/Volumes/DevVault/Apps/Xcode-beta.app`). Xcode 26.6 has no iOS 27 runtime. `pod install` was run in this worktree; Pods are gitignored.
- Command:
  ```bash
  DEVELOPER_DIR=/Volumes/DevVault/Apps/Xcode-beta.app/Contents/Developer \
  xcodebuild test -workspace NumPad.xcworkspace -scheme NumPad \
    -destination "platform=iOS Simulator,id=63A2B051-4FD6-404B-A0B4-FACBF0B38982" \
    -derivedDataPath /tmp/key-opus/home-shell-harden-dd -only-testing:NumPadTests \
    -resultBundlePath /tmp/key-opus/unit2.xcresult CODE_SIGNING_ALLOWED=NO
  ```
- **Result: PASS.** `Executed 1009 tests, with 3 tests skipped and 0 failures`, `** TEST SUCCEEDED **`. The 3 skips are opt-in QWERTY eval benchmarks that skip by design. Log: `/tmp/key-opus/unit2.log`.
- **Not run:** the `NumPadUITests` XCUITest suites.

## Open risks (details in REVIEW_HOME_SHELL.md)

1. **2.1.1 is already live.** A submission needs a new marketing version; it was not bumped, per instructions.
2. **What's New was removed** compared with live (sheet, notification, chip, and the `numpad://whats-new` route). The owner should decide whether that is intended.
3. **Saved setups (profiles), the Studio-based screen, and the `.numpadprofile` document import** are new on iPhone. Either hide them or QA them on a device before release.
4. **The QWERTY gate fix relies on `experimentalUIVisible`** (receipt check) inside the keyboard extension. Verify on TestFlight that the ABC key still appears for Pro testers.
5. **The RC default `full_keyboard_enabled` is still `true`.** It is harmless after the fix, but should be flipped deliberately at GA.
