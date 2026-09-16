# CALIBRATION_PORT_RESULT — rel-2.1.1-home-shell-settings

**Date:** 2026-09-15 (PT)
**Branch:** `james/rel-2.1.1-home-shell-settings`
**Worktree:** `/Users/jamespikover/NumPad/.worktrees/rel-2.1.1-home-shell-settings`
**Source tip:** `origin/codex/keyboard-calibration` @ `b1ac7d46` (includes quick 26-letter commits `d2f1426b`, `b1ac7d46`)

## Outcome

| Item | Status |
|------|--------|
| Version | **2.1.1 (16)** |
| Build (Xcode-beta Debug → device) | **PASS** |
| Install (`devicectl device install app`) | **PASS** |
| Launch | **PASS** |
| Home shell on iPhone | **Classic `HomeViewController`** (no `StudioTabBarController` / `makePhoneShell()` as phone root) |
| ASC submit | **No** — drafts only |

## What was ported

### New files (from calibration tip)
- `NumPad/Controllers/QwertyCalibrationViewController.swift` (quick 26-letter flow)
- `NumPad/Controllers/QwertySwipeCalibrationViewController.swift` (`#if DEBUG && NUMPAD_PRIVATE_SWIPE`)
- `NumPad/Libraries/Qwerty/QwertyCalibrationManifest.swift` (emoji key kinds stripped — home-shell has no `.emojiMode`/`.emojiResult`)
- `NumPad/Libraries/Qwerty/QwertyCalibrationSession.swift`
- `NumPad/Libraries/Qwerty/QwertyCalibrationStore.swift`
- `NumPad/Libraries/Qwerty/QwertyCalibrationTrainer.swift`
- `NumPad/Libraries/Qwerty/QwertySwipeCalibration.swift` (`#if DEBUG && NUMPAD_PRIVATE_SWIPE`)
- Tests: `QwertyCalibrationTests`, `QwertySwipeCalibrationTests`, `QwertyCalibratedRoutingTests`

### Wiring (surgical — not full tip PageHost/KeyboardView)
- `QwertyTouchRouting.calibratedKeyIndex`
- `QwertyKeyboardView` practice mode, physical-touch capture, calibrated routing, geometry callback
- `QwertyPageHost` async profile load + `applyCalibrationForCurrentLayout` (no tip emoji/reliability/PrivateSwipe glide wrap)
- `QwertyGlideGestureRecognizer.sampleTimestamps` (without wrapping entire glide stack in PrivateSwipe)
- Minimal `IPadKeyboardCompositionGeometry` + `IPadQwertyLayout` / `FullKeyboardNumpadSide` / `NumpadWidthSize` + `UserPrefs` accessors for calibration canvas layout
- `UserDefaults.appGroupIdentifier` = production `group.morevoltage.numpad.container` (no private-swipe group swap)

### Home entry points (classic Home → NumPad Type)
In hybrid `QwertySetupViewController`:
- **Calibrate typing** → full-screen `QwertyCalibrationViewController`
- **Calibrate swipe (private)** → only when `DEBUG && NUMPAD_PRIVATE_SWIPE`
- **Reset Typing Personalization** → clears `QwertyCalibrationStore` then legacy touch/dictionary; swipe store under PrivateSwipe flag

### Kept / avoided
- Live monetization files from `11296b01` untouched
- Phone root remains classic Home
- Did **not** require LettersStudio / Studio tab shell
- Did **not** add PrivateSwipe entitlements / `NumPad-PrivateSwipe` scheme / CI guard scripts
- pbxproj: single SOURCE_ROOT refs under a Calibration group (no double-listed paths)

## Residual gaps / notes

1. **Private swipe calibration** needs `NUMPAD_PRIVATE_SWIPE` + PrivateSwipe scheme/entitlements from calibration tip to appear/run. Main Debug scheme is enough for **tap** calibration.
2. Tip’s full PageHost (emoji mode, suggestion coordinator, reliability refactor) and tip’s PrivateSwipe wrap of the entire glide stack were **not** taken — glide stays DARK via `FeatureFlags.effective()` on main Debug.
3. Manifest fingerprint identity omits emoji key kinds (absent on this cut).
4. No ASC / TestFlight upload from this pass.

## Build / install

```
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
xcodebuild -workspace NumPad.xcworkspace -scheme NumPad -configuration Debug \
  -destination 'id=00008150-001E0CEE3C41401C' -derivedDataPath /tmp/NumPad-cal-port-dd build
xcrun devicectl device install app --device 00008150-001E0CEE3C41401C \
  /tmp/NumPad-cal-port-dd/Build/Products/Debug-iphoneos/NumPad.app
```

Install + launch both succeeded on device `00008150-001E0CEE3C41401C`.

## HEAD

_(filled after commit)_
