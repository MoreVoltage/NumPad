# RESTORE_RESULT — rel-2.1.1-home-shell-settings

**Date:** 2026-09-15 (PT)
**Branch:** `james/rel-2.1.1-home-shell-settings`
**Worktree:** `/Users/jamespikover/NumPad/.worktrees/rel-2.1.1-home-shell-settings`

## Outcome

| Item | Status |
|------|--------|
| Version | **2.1.1 (15)** |
| Build (Xcode-beta Debug → device) | **PASS** |
| Install (`devicectl device install app`) | **PASS** |
| Launch | **BLOCKED** — device Locked (`SBMainWorkspace` / FBSOpenApplicationErrorDomain 7) |
| Home shell on iPhone | **Code restored** (classic `HomeViewController` + demo field); visual confirm pending unlock |
| StudioTabBar as iPhone root | **No** — phone installs Home only; iPad keeps Studio workspace |

## HEAD

**`ea86df251afb7fdcb874bd1cff8a08134f32e4e5`** (`ea86df25`) — based on `3a3ed78a` + Home/paywall restore.

## What was ported

1. **Base tip:** reset branch to committed QWERTY/Studio tip `3a3ed78a` (not dirty `~/NumPad` uncommitted files).
2. **Phone shell restore:** `ViewController.installContentShell()` now installs classic `HomeViewController` + “Try the NumPad keyboard here” demo field on iPhone; iPad still embeds `IPadStudioWorkspaceViewController`. `StudioTabBarController` is **not** the iPhone root.
3. **Home rows:** from `3a3ed78a` `HomeSettingsModel` / `HomeViewController` — NumPad Type (`.qwerty`) and Typing & Behavior when `FeatureFlags.isFullKeyboardActive` (typing section gated to match).
4. **Live monetization from `11296b01`:**
   - `StoreViewController+Hero.swift`
   - `FeaturesGuideViewController.swift`
   - `Products.storekit` (lifetime + packs only; empty subscription groups)
5. **Kept from `3a3ed78a`:** QWERTY keyboard stack, `TypingBehaviorViewController`, personal dictionary, Store without controls section (moved to Typing & Behavior), glide remains DARK via `effective()`.
6. **Version stamp:** all `MARKETING_VERSION = 2.1.1`, `CURRENT_PROJECT_VERSION = 15` in pbxproj.
7. **Tests:** phone shell orchestration test expects Home (not Studio tabs); HomeSettingsModel gating test added.
8. **Pods:** `pod install` completed in worktree.

## Skipped / residual gaps

- **Calibration screens** from `44579547` / `keyboard-calibration` **not ported** — commit `31a0606a` also pulls PrivateSwipe entitlements, pbxproj target churn, Studio Letters hooks, Podfile delta, and glide keyboard wiring. Deferred to keep this restore compile-clean. Personal dictionary push from QwertySetup remains.
- **Launch / deep-link exercise:** install succeeded; launch + `numpad://debug/fullkeyboard?enabled=1` / `numpad://debug/entitle?pro=1` blocked while phone locked. Routes **exist** in DEBUG (`DebugDeepLinkRoute` + `DeepLinkRouter`). After unlock:
  ```bash
  DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
    xcrun devicectl device process launch --device 00008150-001E0CEE3C41401C com.morevoltage.NumPad
  DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
    xcrun devicectl device process launch --device 00008150-001E0CEE3C41401C \
    --payload-url 'numpad://debug/fullkeyboard?enabled=1' com.morevoltage.NumPad
  DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
    xcrun devicectl device process launch --device 00008150-001E0CEE3C41401C \
    --payload-url 'numpad://debug/entitle?pro=1' com.morevoltage.NumPad
  ```
  Manual fallback: NumPad Pro → Feature Flags (Beta) → enable Full Keyboard; Debug → Simulate Pro Entitlement.
- **No ASC / TestFlight upload** (per hard rules).
- **Dirty `~/NumPad` main checkout not edited.**

## Device

- Destination: James’s iPhone 17 Pro `00008150-001E0CEE3C41401C` (CoreDevice `25422028-6E89-549C-84E4-98E7CFFC4E08`)
- Installed bundle: `com.morevoltage.NumPad` @ 2.1.1 (15)
